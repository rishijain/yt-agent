class AudioDownloadJob < ApplicationJob
  queue_as :default

  def perform(video_id, job_tracking_id)
    Rails.logger.info "Starting audio download for video: #{video_id} (job: #{job_tracking_id})"

    begin
      update_job_status(job_tracking_id, 'processing', 'Downloading audio from video')

      response_data = call_python_download_service(video_id)

      update_job_status(job_tracking_id, 'completed', 'Audio download completed successfully', response_data)

      Rails.logger.info "Audio download completed for video: #{video_id} (job: #{job_tracking_id})"
    rescue => e
      Rails.logger.error "Audio download failed for video: #{video_id} (job: #{job_tracking_id}): #{e.message}"
      update_job_status(job_tracking_id, 'failed', "Download failed: #{e.message}")
      raise e
    end
  end

  private

  def call_python_download_service(video_id)
    require 'net/http'
    require 'uri'
    require 'json'

    base_url = ENV.fetch('TRANSCRIPT_SERVICE_URL', 'http://localhost:8000')
    uri = URI("#{base_url}/videos/download-audio/#{video_id}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 300
    http.open_timeout = 300

    request = Net::HTTP::Get.new(uri.path)
    request['Content-Type'] = 'application/json'

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise "HTTP Error: #{response.code} - #{response.message}"
    end

    JSON.parse(response.body)
  rescue JSON::ParserError
    response.body
  end

  def update_job_status(job_tracking_id, status, message, data = nil)
    job_status = JobStatus.find_by(job_tracking_id: job_tracking_id)
    if job_status
      job_status.update!(
        status: status,
        message: message,
        data: data&.to_json
      )
    else
      Rails.logger.error "Job status not found for tracking ID: #{job_tracking_id}"
    end
  end
end

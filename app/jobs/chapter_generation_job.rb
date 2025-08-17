class ChapterGenerationJob < ApplicationJob
  queue_as :default

  def perform(video_id, job_tracking_id, audio_file_path)
    Rails.logger.info "Starting chapter generation for video: #{video_id} (job: #{job_tracking_id})"

    begin
      update_job_status(job_tracking_id, 'chapter_generation_processing', 'Generating chapters from audio')

      chapters = generate_chapters_with_assemblyai(audio_file_path)

      update_job_status(job_tracking_id, 'completed', 'Chapter generation completed successfully', { chapters: chapters })

      Rails.logger.info "Chapter generation completed for video: #{video_id} (job: #{job_tracking_id})"
    rescue => e
      Rails.logger.error "Chapter generation failed for video: #{video_id} (job: #{job_tracking_id}): #{e.message}"
      update_job_status(job_tracking_id, 'failed', "Chapter generation failed: #{e.message}")
      raise e
    end
  end

  private

  def generate_chapters_with_assemblyai(audio_file_path)
    require 'net/http'
    require 'json'

    base_url = 'https://api.assemblyai.com'
    api_key = ENV.fetch('ASSEMBLYAI_API_KEY')

    headers = {
      'authorization' => api_key,
      'content-type' => 'application/json'
    }

    # Upload audio file
    upload_url = upload_audio_file(base_url, headers, audio_file_path)

    # Request transcription with chapters
    transcript_id = request_transcription(base_url, headers, upload_url)

    # Poll for completion and get chapters
    poll_for_chapters(base_url, headers, transcript_id)
  end

  def upload_audio_file(base_url, headers, audio_file_path)
    uri = URI("#{base_url}/v2/upload")
    request = Net::HTTP::Post.new(uri, headers)
    request.body = File.read(audio_file_path)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    upload_response = http.request(request)

    unless upload_response.is_a?(Net::HTTPSuccess)
      raise "Audio upload failed with status #{upload_response.code}: #{upload_response.body}"
    end

    JSON.parse(upload_response.body)["upload_url"]
  end

  def request_transcription(base_url, headers, upload_url)
    data = {
      "audio_url" => upload_url,
      "auto_chapters" => true
    }

    uri = URI.parse("#{base_url}/v2/transcript")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = data.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise "Transcription request failed with status #{response.code}: #{response.body}"
    end

    response_body = JSON.parse(response.body)
    response_body['id']
  end

  def poll_for_chapters(base_url, headers, transcript_id)
    polling_endpoint = URI.parse("#{base_url}/v2/transcript/#{transcript_id}")
    max_attempts = 60 # 3 minutes with 3-second intervals
    attempts = 0

    while attempts < max_attempts
      polling_http = Net::HTTP.new(polling_endpoint.host, polling_endpoint.port)
      polling_http.use_ssl = true
      polling_request = Net::HTTP::Get.new(polling_endpoint.request_uri, headers)
      polling_response = polling_http.request(polling_request)

      transcription_result = JSON.parse(polling_response.body)

      case transcription_result['status']
      when 'completed'
        return format_chapters(transcription_result['chapters'])
      when 'error'
        raise "Transcription failed: #{transcription_result['error']}"
      else
        Rails.logger.info "Transcription status: #{transcription_result['status']}, attempt #{attempts + 1}"
        sleep(3)
        attempts += 1
      end
    end

    raise "Transcription polling timed out after #{max_attempts} attempts"
  end

  def format_chapters(chapters)
    return [] if chapters.nil?

    chapters.map do |chapter|
      {
        start_time: chapter['start'],
        end_time: chapter['end'],
        headline: chapter['headline'],
        summary: chapter['summary']
      }
    end
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

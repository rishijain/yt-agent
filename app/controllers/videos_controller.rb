class VideosController < ApplicationController
  require 'net/http'
  require 'uri'
  require 'json'

  def transcript
    video_id = params[:video_id]
    language = params[:language] || 'en'

    if video_id.blank?
      return render json: { error: 'video_id is required' }, status: :bad_request
    end

    begin
      transcript_data = fetch_transcript(video_id, language)
      render json: { 
        video_id: video_id,
        language: language,
        transcript: transcript_data 
      }
    rescue => e
      Rails.logger.error "Error fetching transcript: #{e.message}"
      render json: { 
        error: 'Failed to fetch transcript',
        message: e.message 
      }, status: :internal_server_error
    end
  end

  private

  def fetch_transcript(video_id, language)
    base_url = ENV.fetch('TRANSCRIPT_SERVICE_URL', 'http://localhost:8000')
    uri = URI("#{base_url}/videos/transcript/#{video_id}/#{language}")
    
    response = Net::HTTP.get_response(uri)
    
    unless response.is_a?(Net::HTTPSuccess)
      raise "HTTP Error: #{response.code} - #{response.message}"
    end

    JSON.parse(response.body)
  rescue JSON::ParserError
    response.body
  end
end
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

  def chapters
    video_id = params[:video_id]
    language = params[:language] || 'en'

    if video_id.blank?
      return render json: { error: 'video_id is required' }, status: :bad_request
    end

    begin
      # Fetch transcript data
      transcript_data = fetch_transcript(video_id, language)

      # Filter and prepare data for LLM
      filtered_transcript = filter_transcript_for_chapters(transcript_data)

      # Send to LLM for chapter generation
      agent = Agent::Transcript.new
      chapters_response = agent.chat_with_prompt(:analysis, filtered_transcript.to_json)

      # Parse the JSON response from LLM (handle markdown code blocks)
      chapters = parse_llm_json_response(chapters_response)

      render json: {
        video_id: video_id,
        language: language,
        chapters: chapters
      }
    rescue JSON::ParserError => e
      Rails.logger.error "Error parsing LLM response: #{e.message}"
      render json: {
        error: 'Failed to parse chapters response',
        message: e.message
      }, status: :internal_server_error
    rescue => e
      Rails.logger.error "Error generating chapters: #{e.message}"
      render json: {
        error: 'Failed to generate chapters',
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

  def filter_transcript_for_chapters(transcript_data)
    # If transcript_data is already an array of objects with 'start' and 'text' fields, use as is
    if transcript_data.is_a?(Array)
      return transcript_data
    end

    # If it's a hash containing transcript data, extract the array
    if transcript_data.is_a?(Hash)
      # Look for common keys that might contain the transcript array
      transcript_array = transcript_data['transcript'] ||
                        transcript_data['segments'] ||
                        transcript_data['data'] ||
                        transcript_data

      if transcript_array.is_a?(Array)
        return transcript_array
      end
    end

    # Fallback: return the data as is and let the LLM handle it
    transcript_data
  end

  def parse_llm_json_response(response)
    # Remove markdown code blocks if present
    cleaned_response = response.strip

    # Handle ```json ... ``` format
    if cleaned_response.start_with?('```json')
      cleaned_response = cleaned_response.gsub(/^```json\s*/, '').gsub(/\s*```$/, '')
    elsif cleaned_response.start_with?('```')
      cleaned_response = cleaned_response.gsub(/^```\s*/, '').gsub(/\s*```$/, '')
    end

    # Parse the cleaned JSON
    JSON.parse(cleaned_response.strip)
  end
end

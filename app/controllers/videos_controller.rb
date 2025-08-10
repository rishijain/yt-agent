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

      # Calculate video duration and determine chapter limit
      video_duration = calculate_video_duration(filtered_transcript)
      max_chapters = calculate_max_chapters(video_duration)

      # Send to LLM for chapter generation
      agent = Agent::Transcript.new
      
      begin
        chapters_response = agent.chat_with_prompt(:analysis, filtered_transcript.to_json, max_chapters: max_chapters)
      rescue => llm_error
        Rails.logger.error "LLM call failed: #{llm_error.message}"
        
        # Return a fallback response
        chapters_response = '[{"name": "Introduction", "timestamp": "00:00", "start_seconds": 0}]'
      end

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
      transcript_array = transcript_data.dig('transcript', 'snippets') ||
                        transcript_data['transcript'] ||
                        transcript_data['segments'] ||
                        transcript_data['snippets'] ||
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
    chapters = JSON.parse(cleaned_response.strip)
    
    # Validate and fix each chapter
    chapters.map do |chapter|
      validate_and_fix_chapter(chapter)
    end
  end

  def validate_and_fix_chapter(chapter)
    # Ensure required fields exist with defaults
    fixed_chapter = {
      'name' => chapter['name'] || 'Untitled Chapter',
      'timestamp' => chapter['timestamp'] || '00:00',
      'start_seconds' => chapter['start_seconds'] || 0
    }

    # Fix any NaN or undefined values
    if fixed_chapter['name'] == 'undefined' || fixed_chapter['name'].nil?
      fixed_chapter['name'] = 'Untitled Chapter'
    end

    if fixed_chapter['timestamp'] == 'NaN:NaN' || fixed_chapter['timestamp'].nil?
      # Try to generate timestamp from start_seconds
      seconds = fixed_chapter['start_seconds'].to_i
      minutes = seconds / 60
      remaining_seconds = seconds % 60
      fixed_chapter['timestamp'] = sprintf("%02d:%02d", minutes, remaining_seconds)
    end

    # Ensure start_seconds is a valid number
    unless fixed_chapter['start_seconds'].is_a?(Numeric)
      fixed_chapter['start_seconds'] = 0
    end

    fixed_chapter
  end

  def calculate_video_duration(transcript_array)
    return 0 unless transcript_array.is_a?(Array) && transcript_array.any?

    # Find the last segment and calculate total duration
    last_segment = transcript_array.last
    return 0 unless last_segment.is_a?(Hash)

    # Total duration = start time of last segment + duration of last segment
    last_start = last_segment['start'].to_f
    last_duration = last_segment['duration'].to_f
    
    last_start + last_duration
  end

  def calculate_max_chapters(video_duration_seconds)
    # Rule: 5 chapters per 30 minutes (1800 seconds)
    # Formula: (duration / 1800) * 5, rounded up to ensure we don't go below the minimum
    return 5 if video_duration_seconds <= 1800 # Minimum 5 chapters for videos up to 30 mins
    
    chapters_per_30_min = 5
    thirty_minutes = 1800
    
    (video_duration_seconds / thirty_minutes * chapters_per_30_min).ceil
  end
end

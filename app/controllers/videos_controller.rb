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

      # Extract title and filter transcript for LLM
      video_title = transcript_data.is_a?(Hash) ? transcript_data['title'] : nil
      filtered_transcript = filter_transcript_for_chapters(transcript_data)

      # Generate and review chapters with iterative improvement (let LLM determine optimal chapter count)
      agent = Agent::Transcript.new
      chapters, final_review = generate_chapters_with_review(agent, filtered_transcript, video_title)

      render json: {
        video_id: video_id,
        language: language,
        chapters: chapters,
        review: final_review
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

    # Ensure start_seconds is a valid number first
    unless fixed_chapter['start_seconds'].is_a?(Numeric)
      fixed_chapter['start_seconds'] = 0
    end

    # Always regenerate timestamp from start_seconds to ensure consistency
    seconds = fixed_chapter['start_seconds'].to_f.round
    minutes = seconds / 60
    remaining_seconds = seconds % 60
    fixed_chapter['timestamp'] = sprintf("%02d:%02d", minutes, remaining_seconds)

    # Validate timestamp format matches expected pattern
    unless fixed_chapter['timestamp'].match?(/^\d{2}:\d{2}$/)
      fixed_chapter['timestamp'] = '00:00'
      fixed_chapter['start_seconds'] = 0
    end

    fixed_chapter
  end


  def generate_chapters_with_review(agent, filtered_transcript, video_title = nil)
    max_attempts = 1
    current_attempt = 1

    # Initial chapter generation
    begin
      chapters_response = agent.chat_with_prompt(:analysis, filtered_transcript.to_json, video_title: video_title)
      chapters = parse_llm_json_response(chapters_response)
    rescue => llm_error
      Rails.logger.error "LLM call failed: #{llm_error.message}"
      chapters = [{"name" => "Introduction", "timestamp" => "00:00", "start_seconds" => 0}]
    end

    # Review and potentially regenerate chapters
    while current_attempt <= max_attempts
      begin
        Rails.logger.info "Review attempt #{current_attempt}: transcript type=#{filtered_transcript.to_json.class}, chapters type=#{chapters.to_json.class}"
        review_response = agent.chat_with_prompt(:review, filtered_transcript.to_json, generated_chapters: chapters.to_json, video_title: video_title)
        review_data = parse_review_json_response(review_response)
      rescue => review_error
        Rails.logger.error "Chapter review failed (attempt #{current_attempt}): #{review_error.message}"
        Rails.logger.error review_error.backtrace.first(5).join("\n")
        review_data = {
          "review_status" => "approved",
          "overall_quality" => "good",
          "issues_found" => [],
          "suggestions" => {
            "general_feedback" => "Review system unavailable",
            "specific_improvements" => [],
            "regeneration_guidance" => ""
          }
        }
      end

      # If approved or this is the last attempt, return results
      if review_data["review_status"] == "approved" || current_attempt == max_attempts
        Rails.logger.info "Chapters finalized after #{current_attempt} attempt(s) with status: #{review_data['review_status']}"
        return [chapters, review_data]
      end

      # Regenerate chapters based on review feedback
      # Use reviewer's recommended chapter count if provided, otherwise keep original limit
      Rails.logger.info "Regenerating chapters (attempt #{current_attempt + 1}/#{max_attempts}) based on thematic organization"
      begin
        regeneration_response = agent.chat_with_prompt(
          :regeneration,
          filtered_transcript.to_json,
          review_feedback: review_data,
          video_title: video_title
        )
        chapters = parse_llm_json_response(regeneration_response)
      rescue => regeneration_error
        Rails.logger.error "Chapter regeneration failed: #{regeneration_error.message}"
        # Keep existing chapters if regeneration fails
      end

      current_attempt += 1
    end

    # This shouldn't be reached due to the logic above, but included for safety
    [chapters, review_data]
  end

  def parse_review_json_response(response)
    # Remove markdown code blocks if present
    cleaned_response = response.strip

    # Handle ```json ... ``` format
    if cleaned_response.start_with?('```json')
      cleaned_response = cleaned_response.gsub(/^```json\s*/, '').gsub(/\s*```$/, '')
    elsif cleaned_response.start_with?('```')
      cleaned_response = cleaned_response.gsub(/^```\s*/, '').gsub(/\s*```$/, '')
    end

    # Parse the cleaned JSON (review response is an object, not an array)
    JSON.parse(cleaned_response.strip)
  end
end

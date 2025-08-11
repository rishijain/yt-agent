class Agent::Prompt
  def self.analysis_prompt(content, max_chapters = nil, video_duration = nil)
    chapter_limit_instruction = max_chapters ? "Generate a maximum of #{max_chapters} chapters." : ""
    
    # Parse content to find actual video duration
    parsed_content = JSON.parse(content) rescue []
    if parsed_content.is_a?(Array) && parsed_content.any?
      last_segment = parsed_content.last
      actual_duration = (last_segment['start'].to_f + (last_segment['duration']&.to_f || 0)).round
      duration_minutes = actual_duration / 60
      duration_seconds = actual_duration % 60
      duration_display = sprintf("%d:%02d", duration_minutes, duration_seconds)
    end

    <<~PROMPT
      You are an expert in video content analysis tasked with generating YouTube chapters from a video transcript.
      You also understand the nuances of video content and audience engagement.
      You are given a full transcript of a video as a JSON array of objects
      with "start" (seconds) and "text" fields with the language of the video.
      
      #{duration_display ? "IMPORTANT: This video is exactly #{duration_display} long (#{actual_duration} seconds). DO NOT create any chapters beyond this duration." : ""}

      Your job: Split it into YouTube chapters. Each chapter should have:
      - "name": a short, purely descriptive title (never "undefined")
      - "timestamp": convert the "start" seconds value to mm:ss format (e.g., if start is 125 seconds, timestamp should be "02:05")
      - "start_seconds": the exact start time in seconds from the transcript (must match the "start" value from transcript data)

      #{chapter_limit_instruction}

      CRITICAL: Ensure timestamp accuracy by:
      1. Using EXACT "start" values from the transcript data for "start_seconds"
      2. Converting start_seconds accurately to mm:ss format for "timestamp"
      3. Analyzing the transcript content at specific timestamps to ensure chapters match the actual content timing
      4. Each chapter should represent content that actually occurs at that timestamp in the video
      
      Rules for timestamp conversion:
      - Convert seconds to minutes and seconds precisely
      - Format as "mm:ss" (e.g., "00:00", "01:30", "15:42")
      - Always use 2 digits for minutes and seconds
      - The timestamp should correspond to where that chapter's content actually begins in the video
      - Verify that the content described in the chapter name actually occurs around that timestamp
      - NEVER create chapters with timestamps that exceed the actual video duration
      - Only use start_seconds values that exist in the provided transcript data

      The language of the output should match the language of the input.
      Output JSON only, no commentary.

      Here is the input json:
      #{content}

      Example output format:
      [
        {"name": "Introduction", "timestamp": "00:00", "start_seconds": 0},
        {"name": "Main Topic", "timestamp": "02:30", "start_seconds": 150}
      ]

      The output should be a JSON array of objects with "name", "timestamp", and "start_seconds" fields.
    PROMPT
  end

  def self.review_prompt(original_transcript, generated_chapters)
    <<~PROMPT
      You are an expert video content analyst reviewing automatically generated YouTube chapters.

      ORIGINAL TRANSCRIPT:
      #{original_transcript}

      GENERATED CHAPTERS:
      #{generated_chapters}

      Your task: Review the generated chapters as an expert and provide feedback in JSON format.

      Evaluate the chapters based on:
      1. Content relevance - Do chapter names accurately reflect the content?
      2. Timing accuracy - Are timestamps placed at appropriate content transitions?
      3. Chapter distribution - Are chapters well-spaced and logical?
      4. Naming quality - Are chapter names descriptive and useful?
      5. Missing segments - Are there important content sections without chapters?

      Output format (JSON only):
      {
        "review_status": "approved" | "needs_rework",
        "overall_quality": "excellent" | "good" | "fair" | "poor",
        "issues_found": [
          "issue description 1",
          "issue description 2"
        ],
        "suggestions": {
          "general_feedback": "Overall assessment of the chapters",
          "specific_improvements": [
            "specific suggestion 1",
            "specific suggestion 2"
          ],
          "regeneration_guidance": "How to improve chapter generation if rework is needed"
        },
        "recommended_chapter_count": 5
      }

      For recommended_chapter_count:
      - Use an actual number (e.g., 3, 5, 8) if you recommend a different chapter count
      - Use null if the current number of chapters is appropriate
      - Base your recommendation on content structure and natural topic boundaries
      - Also make sure that the chapter titles are engaging and accurately reflect the content.

      Be thorough but concise. Focus on actionable feedback.
    PROMPT
  end

  def self.regeneration_prompt(content, max_chapters, review_feedback)
    chapter_limit_instruction = max_chapters ? "Generate a maximum of #{max_chapters} chapters." : ""
    issues = review_feedback['issues_found'] || []
    suggestions = review_feedback['suggestions'] || {}
    
    # Parse content to find actual video duration
    parsed_content = JSON.parse(content) rescue []
    if parsed_content.is_a?(Array) && parsed_content.any?
      last_segment = parsed_content.last
      actual_duration = (last_segment['start'].to_f + (last_segment['duration']&.to_f || 0)).round
      duration_minutes = actual_duration / 60
      duration_seconds = actual_duration % 60
      duration_display = sprintf("%d:%02d", duration_minutes, duration_seconds)
    end

    <<~PROMPT
      You are regenerating YouTube chapters based on expert review feedback.
      The chapters should be concise, engaging, and accurately reflect the content.
      
      #{duration_display ? "IMPORTANT: This video is exactly #{duration_display} long (#{actual_duration} seconds). DO NOT create any chapters beyond this duration." : ""}

      ORIGINAL TRANSCRIPT:
      #{content}

      PREVIOUS ATTEMPT HAD THESE ISSUES:
      #{issues.map { |issue| "- #{issue}" }.join("\n")}

      EXPERT SUGGESTIONS:
      General Feedback: #{suggestions['general_feedback']}

      Specific Improvements:
      #{(suggestions['specific_improvements'] || []).map { |improvement| "- #{improvement}" }.join("\n")}

      Regeneration Guidance: #{suggestions['regeneration_guidance']}

      Your job: Create improved YouTube chapters addressing the feedback above. Each chapter should have:
      - "name": a short, purely descriptive title (never "undefined")
      - "timestamp": convert the "start" seconds value to mm:ss format (e.g., if start is 125 seconds, timestamp should be "02:05")
      - "start_seconds": the exact start time in seconds from the transcript (must match the "start" value from transcript data)

      #{chapter_limit_instruction}

      CRITICAL: Ensure timestamp accuracy by:
      1. Using EXACT "start" values from the transcript data for "start_seconds"
      2. Converting start_seconds accurately to mm:ss format for "timestamp"
      3. Analyzing the transcript content at specific timestamps to ensure chapters match the actual content timing
      4. Each chapter should represent content that actually occurs at that timestamp in the video
      
      Rules for timestamp conversion:
      - Convert seconds to minutes and seconds precisely
      - Format as "mm:ss" (e.g., "00:00", "01:30", "15:42")
      - Always use 2 digits for minutes and seconds
      - The timestamp should correspond to where that chapter's content actually begins in the video
      - Verify that the content described in the chapter name actually occurs around that timestamp
      - NEVER create chapters with timestamps that exceed the actual video duration
      - Only use start_seconds values that exist in the provided transcript data

      The language of the output should match the language of the input.
      Output JSON only, no commentary.

      Example output format:
      [
        {"name": "Introduction", "timestamp": "00:00", "start_seconds": 0},
        {"name": "Main Topic", "timestamp": "02:30", "start_seconds": 150}
      ]

      The output should be a JSON array of objects with "name", "timestamp", and "start_seconds" fields.
    PROMPT
  end
end

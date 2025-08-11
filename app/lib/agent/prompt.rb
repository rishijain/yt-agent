class Agent::Prompt
  def self.analysis_prompt(content, max_chapters = nil, video_title = nil)
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

      #{video_title ? "Video Title: \"#{video_title}\"" : ""}
      #{duration_display ? "Video Duration: #{duration_display} (#{actual_duration} seconds)" : ""}

      Your job: Split it into YouTube chapters based on MAJOR themes and content sections. Focus on:
      - Identifying significant topic changes and major content themes
      - Creating chapters that represent substantial content blocks, not minute details
      - Ensuring each chapter represents a meaningful segment that viewers would want to navigate to
      - Aim for chapters that are typically 3-10 minutes long for good user experience
      #{video_title ? "- Use the video title as context to create chapter names that align with the overall theme" : ""}

      Each chapter should have:
      - "name": a short, purely descriptive title reflecting the main theme (never "undefined")
      - "timestamp": convert the "start" seconds value to mm:ss format (e.g., if start is 125 seconds, timestamp should be "02:05")
      - "start_seconds": the exact start time in seconds from the transcript (must match the "start" value from transcript data)

      Guidelines for chapter creation:
      1. Focus on identifying major content themes and natural topic transitions
      2. Provide approximate timing in start_seconds (will be automatically mapped to actual transcript timestamps)
      3. Ensure chapter names reflect the actual content discussed at those times

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

  def self.review_prompt(original_transcript, generated_chapters, video_title = nil)
    <<~PROMPT
      You are an expert video content analyst reviewing automatically generated YouTube chapters.

      #{video_title ? "Video Title: \"#{video_title}\"" : ""}

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
      #{video_title ? "6. Title alignment - Do chapter names align with the overall theme indicated by the video title?" : ""}

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

  def self.regeneration_prompt(content, max_chapters, review_feedback, video_title = nil)
    # Remove rigid chapter limit, focus on thematic organization
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

      #{video_title ? "Video Title: \"#{video_title}\"" : ""}
      #{duration_display ? "Video Duration: #{duration_display} (#{actual_duration} seconds)" : ""}


      ORIGINAL TRANSCRIPT:
      #{content}

      PREVIOUS ATTEMPT HAD THESE ISSUES:
      #{issues.map { |issue| "- #{issue}" }.join("\n")}

      EXPERT SUGGESTIONS:
      General Feedback: #{suggestions['general_feedback']}

      Specific Improvements:
      #{(suggestions['specific_improvements'] || []).map { |improvement| "- #{improvement}" }.join("\n")}

      Regeneration Guidance: #{suggestions['regeneration_guidance']}

      Your job: Create improved YouTube chapters addressing the feedback above. Focus on MAJOR themes and content sections:
      - Identify significant topic changes and major content themes
      - Create chapters that represent substantial content blocks, not minute details
      - Ensure each chapter represents a meaningful segment that viewers would want to navigate to
      - Aim for chapters that are typically 3-10 minutes long for good user experience
      #{video_title ? "- Use the video title as context to create chapter names that align with the overall theme" : ""}

      Each chapter should have:
      - "name": a short, purely descriptive title reflecting the main theme (never "undefined")
      - "timestamp": convert the "start" seconds value to mm:ss format (e.g., if start is 125 seconds, timestamp should be "02:05")
      - "start_seconds": the exact start time in seconds from the transcript (must match the "start" value from transcript data)

      Guidelines for chapter creation:
      1. Focus on identifying major content themes and natural topic transitions
      2. Provide approximate timing in start_seconds (will be automatically mapped to actual transcript timestamps)
      3. Ensure chapter names reflect the actual content discussed at those times

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

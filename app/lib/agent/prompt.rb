class Agent::Prompt
  def self.analysis_prompt(content, max_chapters = nil)
    chapter_limit_instruction = max_chapters ? "Generate a maximum of #{max_chapters} chapters." : ""
    
    <<~PROMPT
      You are given a full transcript of a video as a JSON array of objects
      with "start" (seconds) and "text" fields with the language of the video.

      Your job: Split it into YouTube chapters. Each chapter should have:
      - "name": a short, purely descriptive title (never "undefined")
      - "timestamp": convert the "start" seconds value to mm:ss format (e.g., if start is 125 seconds, timestamp should be "02:05")
      - "start_seconds": the original start time in seconds as a number

      #{chapter_limit_instruction}

      Rules for timestamp conversion:
      - Convert seconds to minutes and seconds
      - Format as "mm:ss" (e.g., "00:00", "01:30", "15:42")
      - Always use 2 digits for minutes and seconds

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
        "recommended_chapter_count": number_or_null
      }

      Be thorough but concise. Focus on actionable feedback.
    PROMPT
  end

  def self.regeneration_prompt(content, max_chapters, review_feedback)
    chapter_limit_instruction = max_chapters ? "Generate a maximum of #{max_chapters} chapters." : ""
    issues = review_feedback['issues_found'] || []
    suggestions = review_feedback['suggestions'] || {}
    
    <<~PROMPT
      You are regenerating YouTube chapters based on expert review feedback.

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
      - "start_seconds": the original start time in seconds as a number

      #{chapter_limit_instruction}

      Rules for timestamp conversion:
      - Convert seconds to minutes and seconds
      - Format as "mm:ss" (e.g., "00:00", "01:30", "15:42")
      - Always use 2 digits for minutes and seconds

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

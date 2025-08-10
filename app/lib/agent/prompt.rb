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
end

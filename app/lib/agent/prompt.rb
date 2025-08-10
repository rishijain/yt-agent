class Agent::Prompt
  def self.analysis_prompt(content)
    <<~PROMPT
      You are given a full transcript of a video as a JSON array of objects
      with "start" (seconds) and "text" fields with the language of the video.

      Your job: Split it into YouTube chapters. Each chapter should have:
      - "name": a short, purely descriptive title
      - "timestamp": in mm:ss format from the "start" field of the first line in that chapter

      The language of the output should match the language of the input.
      Output JSON only, no commentary.

      Here is the input json:
      #{content}

      The output should be a JSON array of objects with "name" and "timestamp" fields.
    PROMPT
  end
end

class Agent::Prompt
  def self.basic_prompt(content)
    <<~PROMPT
      Please analyze the following content:
      
      #{content}
    PROMPT
  end

  def self.analysis_prompt(content)
    <<~PROMPT
      Please provide a detailed analysis of the following content. Include key themes, writing style, and main points:
      
      #{content}
    PROMPT
  end

  def self.question_prompt(content)
    <<~PROMPT
      Based on the following content, generate 3-5 thoughtful questions that would help someone better understand the topic:
      
      #{content}
    PROMPT
  end
end
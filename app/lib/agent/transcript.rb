class Agent::Transcript
  def initialize
    @llm = Agent::Llm.new
    @prompt = Agent::Prompt
  end

  def chat(message)
    @llm.chat(message)
  end

  def chat_with_prompt(prompt_type, content, options = {})
    case prompt_type
    when :analysis
      prompt = @prompt.analysis_prompt(content, options[:max_chapters], options[:video_title])
    when :review
      prompt = @prompt.review_prompt(content, options[:generated_chapters], options[:video_title])
    when :regeneration
      prompt = @prompt.regeneration_prompt(content, options[:max_chapters], options[:review_feedback], options[:video_title])
    else
      prompt = @prompt.send("#{prompt_type}_prompt", content)
    end
    @llm.chat(prompt)
  end
end
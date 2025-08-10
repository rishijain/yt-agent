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
      prompt = @prompt.send("#{prompt_type}_prompt", content, options[:max_chapters])
    else
      prompt = @prompt.send("#{prompt_type}_prompt", content)
    end
    @llm.chat(prompt)
  end
end
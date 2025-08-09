class Agent::Transcript
  def initialize
    @llm = Agent::Llm.new
    @prompt = Agent::Prompt
  end

  def chat(message)
    @llm.chat(message)
  end

  def chat_with_prompt(prompt_type, content)
    prompt = @prompt.send("#{prompt_type}_prompt", content)
    @llm.chat(prompt)
  end
end
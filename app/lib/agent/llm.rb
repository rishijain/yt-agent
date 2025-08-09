class Agent::Llm
  def initialize
    @client = Langchain::LLM::OpenAI.new(
                api_key: ENV["OPENAI_API_KEY"],
                default_options: { temperature: 0.7 }
              )
  end

  def chat(prompt)
    messages = [ system_prompt, user_prompt(prompt) ]
    response = @client.chat(messages: messages)
    response.raw_response.dig("choices", 0, "message", "content").strip
  end

  private

  def system_prompt
    { role: "system", content: "You are a helpful AI assistant" }
  end

  def user_prompt(prompt)
    { role: "user", content: prompt }
  end
end
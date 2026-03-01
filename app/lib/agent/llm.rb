class Agent::Llm
  def initialize
    @client = Anthropic::Client.new(
      api_key: ENV["ANTHROPIC_API_KEY"]
    )
  end

  def chat(prompt)
    response = @client.messages.create(
      model: "claude-sonnet-4-5-20250929",
      max_tokens: 4096,
      system: "You are a helpful AI assistant",
      messages: [
        { role: "user", content: prompt }
      ]
    )

    # Extract content from the response
    response.content.first.text
  end
end
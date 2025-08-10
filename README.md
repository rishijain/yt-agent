# YouTube Chapters Backend

A Rails API backend service that automatically generates YouTube video chapters using AI/LLM technology. The service fetches video transcripts and uses OpenAI to intelligently create chapter breakdowns with timestamps.

## Features

- **Video Transcript API**: Retrieve video transcripts in multiple languages
- **AI-Powered Chapter Generation**: Automatically create meaningful chapter divisions using OpenAI
- **Intelligent Chapter Review**: Built-in review system that evaluates and improves chapter quality
- **Multi-language Support**: Support for different transcript languages
- **Smart Chapter Limits**: Dynamic chapter count based on video duration (10 chapters per 30 minutes)
- **Iterative Improvement**: Up to 3 attempts to refine chapters based on AI feedback

## API Endpoints

### Video Transcript

```
GET /videos/:video_id/transcript/:language
GET /videos/:video_id/transcript
```

Fetches the transcript for a given YouTube video ID.

**Parameters:**
- `video_id`: YouTube video ID
- `language`: Language code (optional, defaults to 'en')

### Video Chapters

```
GET /videos/:video_id/chapters/:language
GET /videos/:video_id/chapters
```

Generates AI-powered chapters for a YouTube video based on its transcript.

**Parameters:**
- `video_id`: YouTube video ID
- `language`: Language code (optional, defaults to 'en')

## Architecture

### Core Components

- **VideosController**: Main API controller handling transcript and chapter requests
- **Agent::Transcript**: Orchestrates LLM interactions for chapter generation
- **Agent::Llm**: OpenAI client wrapper with temperature controls
- **Agent::Prompt**: Manages specialized prompts for analysis, review, and regeneration

### AI Workflow

1. **Transcript Analysis**: Initial chapter generation based on video content
2. **Expert Review**: AI reviewer evaluates chapter quality and placement
3. **Iterative Improvement**: Up to 3 regeneration attempts based on feedback
4. **Final Validation**: Ensures proper formatting and handles edge cases

## Setup

### Prerequisites

- Ruby 3.x
- PostgreSQL
- OpenAI API key
- Access to transcript service

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   bundle install
   ```

3. Set up environment variables:
   ```bash
   cp .env.example .env
   ```

4. Configure environment variables in `.env`:
   ```
   OPENAI_API_KEY=your_openai_api_key
   TRANSCRIPT_SERVICE_URL=http://localhost:8000
   ```

5. Set up database:
   ```bash
   rails db:create
   rails db:migrate
   ```

6. Start the server:
   ```bash
   rails server
   ```

## Environment Variables

- `OPENAI_API_KEY`: OpenAI API key for LLM functionality
- `TRANSCRIPT_SERVICE_URL`: URL of the transcript service (defaults to http://localhost:8000)

## Development

Start the development server:
```bash
rails server
```

## Dependencies

### Core Dependencies
- **Rails 8.0.2**: Web framework
- **PostgreSQL**: Database
- **Puma**: Web server
- **langchainrb**: LLM integration framework
- **ruby-openai**: OpenAI API client
- **dotenv-rails**: Environment variable management

### Caching & Background Jobs
- **solid_cache**: Database-backed Rails cache
- **solid_queue**: Database-backed Active Job
- **solid_cable**: Database-backed Action Cable

## Health Check

The application provides a health check endpoint at `/up` for monitoring and load balancer integration.

## Contributing

1. Fork the repository
2. Create your feature branch
3. Submit a pull request

## License

This project is part of AI experiments for YouTube content processing.

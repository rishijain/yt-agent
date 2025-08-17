class JobStatus < ApplicationRecord
  validates :job_tracking_id, presence: true, uniqueness: true
  validates :status, presence: true
  
  VALID_STATUSES = %w[queued processing audio_download_completed chapter_generation_processing completed failed].freeze
  validates :status, inclusion: { in: VALID_STATUSES }
  
  scope :by_status, ->(status) { where(status: status) }
  scope :for_video, ->(video_id) { where(video_id: video_id) }
  
  def data_json
    return {} if data.blank?
    JSON.parse(data)
  rescue JSON::ParserError
    {}
  end
  
  def data_json=(value)
    self.data = value.to_json
  end
  
  def queued?
    status == 'queued'
  end
  
  def processing?
    status == 'processing'
  end
  
  def completed?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  def audio_download_completed?
    status == 'audio_download_completed'
  end
  
  def chapter_generation_processing?
    status == 'chapter_generation_processing'
  end
end
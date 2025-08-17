class CreateJobStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :job_statuses do |t|
      t.string :job_tracking_id, null: false
      t.string :status, null: false
      t.text :message
      t.text :data
      t.string :video_id

      t.timestamps
    end
    add_index :job_statuses, :job_tracking_id, unique: true
  end
end

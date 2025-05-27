class CreateApiPlaygroundApiKeys < ActiveRecord::Migration[7.0]
  def change
    create_table :api_playground_api_keys do |t|
      t.string :token, null: false, index: { unique: true }
      t.datetime :expires_at, null: false
      t.datetime :last_used_at
      t.timestamps
    end
  end
end 
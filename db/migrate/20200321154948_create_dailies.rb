class CreateDailies < ActiveRecord::Migration[6.0]
  def change
    create_table :dailies do |t|
      t.string :date
      t.string :territory
      t.string :territoryparent
      t.boolean :summary
      t.string :confirmed
      t.string :recovered
      t.string :deaths
      t.float :latitude
      t.float :longitude

      t.timestamps
    end
  end
end

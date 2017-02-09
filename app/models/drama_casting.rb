# rubocop:disable Metrics/LineLength
# == Schema Information
#
# Table name: drama_castings
#
#  id                 :integer          not null, primary key
#  locale             :string           not null, indexed => [drama_character_id, person_id]
#  notes              :string
#  drama_character_id :integer          not null, indexed => [person_id, locale], indexed
#  licensor_id        :integer
#  person_id          :integer          not null, indexed => [drama_character_id, locale], indexed
#
# Indexes
#
#  index_drama_castings_on_character_person_locale  (drama_character_id,person_id,locale) UNIQUE
#  index_drama_castings_on_drama_character_id       (drama_character_id)
#  index_drama_castings_on_person_id                (person_id)
#
# Foreign Keys
#
#  fk_rails_13a6ca2d95  (person_id => people.id)
#  fk_rails_25f32514ae  (drama_character_id => drama_characters.id)
#  fk_rails_aef2c89cbe  (licensor_id => producers.id)
#
# rubocop:enable Metrics/LineLength

class DramaCasting < ApplicationRecord
  validates :locale, length: { maximum: 20 }
  validates :notes, length: { maximum: 140 }

  belongs_to :drama_character, required: true
  belongs_to :person, required: true
  belongs_to :licensor, class_name: 'Producer'
end
class GroupServer < ActiveRecord::Base
  belongs_to :server
  belongs_to :group
end

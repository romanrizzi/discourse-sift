require_dependency 'reviewable_serializer'

class ReviewableSiftPostSerializer < ReviewableSerializer
  payload_attributes :post_cooked
end

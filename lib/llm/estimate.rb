# frozen_string_literal: true

##
# The {LLM::Estimate LLM::Estimate} class represents an estimated
# cost breakdown for a provider request. It stores the estimated
# input and output costs separately and can return the total.
#
# @attr [BigDecimal] input_costs
#   Returns the estimated input cost
# @attr [BigDecimal] output_costs
#   Returns the estimated output cost
class LLM::Estimate < Struct.new(:input_costs, :output_costs)
  ##
  # @return [BigDecimal]
  #  Returns the total estimated cost
  def total
    input_costs + output_costs
  end

  ##
  # @return [String]
  #  Returns the total estimated cost in a human friendly format
  def to_s
    total.to_s("F")
  end
end

require "test_helper"

class BusinessDaysTest < ActiveSupport::TestCase
  test "suma saltando fines de semana" do
    friday = Date.new(2026, 10, 30)

    assert_equal Date.new(2026, 11, 2), BusinessDays.add(friday, 1)
    assert_equal Date.new(2026, 11, 6), BusinessDays.add(friday, 5)
  end

  test "cuenta días hábiles entre fechas, negativo si ya pasó" do
    monday = Date.new(2026, 10, 26)

    assert_equal 5, BusinessDays.between(monday, Date.new(2026, 11, 2))
    assert_equal(-5, BusinessDays.between(Date.new(2026, 11, 2), monday))
    assert_equal 0, BusinessDays.between(monday, monday)
  end
end

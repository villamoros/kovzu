require "test_helper"

class SamplingPlanTest < ActiveSupport::TestCase
  test "RF-18: tabla fija según el tamaño del lote" do
    assert_equal 0, SamplingPlan.sample_size(nil)
    assert_equal 2, SamplingPlan.sample_size(2)
    assert_equal 8, SamplingPlan.sample_size(50)
    assert_equal 13, SamplingPlan.sample_size(60)
    assert_equal 80, SamplingPlan.sample_size(1_000)
    assert_equal 125, SamplingPlan.sample_size(2_000)
    assert_equal 1_250, SamplingPlan.sample_size(900_000)
  end

  test "nunca pide más unidades que las del lote" do
    assert_equal 1, SamplingPlan.sample_size(1)
  end

  test "muestra el rango de la fila" do
    assert_equal "1.201–3.200", SamplingPlan.range_label(2_000)
    assert_equal "2–8", SamplingPlan.range_label(5)
  end
end

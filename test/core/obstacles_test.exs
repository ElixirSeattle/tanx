defmodule Tanx.ObstaclesTest do
  use ExUnit.Case


  @epsilon 0.00001

  def assert_structure_in_epsilon([h1 | t1], [h2 | t2]) do
    assert_structure_in_epsilon(h1, h2)
    assert_structure_in_epsilon(t1, t2)
  end
  def assert_structure_in_epsilon(x, y) when is_tuple(x) and is_tuple(y) do
    assert_structure_in_epsilon(Tuple.to_list(x), Tuple.to_list(y))
  end
  def assert_structure_in_epsilon(x, y) when is_number(x) and is_number(y) do
    assert_in_delta(x, y, @epsilon)
  end
  def assert_structure_in_epsilon(x, y) do
    assert x == y
  end


  test "decompose single segment wall" do
    wall = [{-1, 1}, {1, 2}]
    decomposed = Tanx.Core.Obstacles.decompose_wall(wall)
    expected = {
      [
        {{0, -1}, {-1, 1}, {-2, 3}},
        {{0, 4}, {1, 2}, {2, 0}},
        {{1, 2}, {-1, 1}},
        {{-1, 1}, {1, 2}}
      ],
      [
        {{1, 2}, {-1, 1}},
        {{-1, 1}, {1, 2}}
      ]
    }
    assert decomposed == expected
  end


  test "decompose triangle wall" do
    wall = [{-1, 1}, {1, 2}, {3, 0}]
    decomposed = Tanx.Core.Obstacles.decompose_wall(wall)
    expected = {
      [
        {{-2, -3}, {-1, 1}, {-2, 3}},
        {{5, 2}, {3, 0}, {2, -4}},
        {{0, 4}, {1, 2}, {3, 4}},
        {{3, 0}, {-1, 1}},
        {{1, 2}, {3, 0}},
        {{-1, 1}, {1, 2}}
      ],
      [
        {{3, 0}, {-1, 1}},
        {{1, 2}, {3, 0}},
        {{-1, 1}, {1, 2}}
      ]
    }
    assert decomposed == expected
  end


  test "decompose quadrilateral with a concave corner" do
    root2 = :math.sqrt(2)
    wall = [{-1, -1}, {0, 1}, {1, -1}, {0, 0}]
    decomposed = Tanx.Core.Obstacles.decompose_wall(wall)
    expected = {
      [
        {{0, 0}, {root2/2, -root2/2}, {0, -1}, {-root2/2, -root2/2}, 1, root2},
        {{0, -2}, {-1, -1}, {-3, 0}},
        {{3, 0}, {1, -1}, {0, -2}},
        {{-2, 2}, {0, 1}, {2, 2}},
        {{0, 0}, {-1, -1}},
        {{1, -1}, {0, 0}},
        {{0, 1}, {1, -1}},
        {{-1, -1}, {0, 1}}
      ],
      [
        {{0, 0}, {-1, -1}},
        {{1, -1}, {0, 0}},
        {{0, 1}, {1, -1}},
        {{-1, -1}, {0, 1}}
      ]
    }

    assert_structure_in_epsilon(decomposed, expected)
  end


  test "force from single segment wall, too far" do
    wall = [{-1, 0}, {1, 2}]
    force = wall
      |> Tanx.Core.Obstacles.decompose_wall
      |> Tanx.Core.Obstacles.force_from_decomposed_wall({-2, 1}, 1)
    assert_structure_in_epsilon(force, {0.0, 0.0})
  end


  test "force from single segment wall, first segment" do
    wall = [{-1, 0}, {1, 2}]
    force = wall
      |> Tanx.Core.Obstacles.decompose_wall
      |> Tanx.Core.Obstacles.force_from_decomposed_wall({-0.5, 1.5}, :math.sqrt(2))
    assert_structure_in_epsilon(force, {-0.5, 0.5})
  end


  test "force from single segment wall, second segment" do
    wall = [{-1, 0}, {1, 2}]
    force = wall
      |> Tanx.Core.Obstacles.decompose_wall
      |> Tanx.Core.Obstacles.force_from_decomposed_wall({0.0, 0.0}, :math.sqrt(2))
    assert_structure_in_epsilon(force, {0.5, -0.5})
  end


  test "force from single segment wall, first corner" do
    wall = [{-1, 0}, {1, 2}]
    force = wall
      |> Tanx.Core.Obstacles.decompose_wall
      |> Tanx.Core.Obstacles.force_from_decomposed_wall({1.0, 2.5}, 1.0)
    assert_structure_in_epsilon(force, {0.0, 0.5})
  end


  test "force from single segment wall, second corner" do
    wall = [{-1, 0}, {1, 2}]
    force = wall
      |> Tanx.Core.Obstacles.decompose_wall
      |> Tanx.Core.Obstacles.force_from_decomposed_wall({-1.5, -0.5}, :math.sqrt(2))
    assert_structure_in_epsilon(force, {-0.5, -0.5})
  end


  test "force from single segment wall, both corner and segment" do
    wall = [{-1, 0}, {1, 2}]
    force = wall
      |> Tanx.Core.Obstacles.decompose_wall
      |> Tanx.Core.Obstacles.force_from_decomposed_wall({0.5, 2.5}, :math.sqrt(2))
    assert_structure_in_epsilon(force, {-0.5, 0.5})
  end


  test "force from a concave corner" do
    wall = [{-2, -2}, {0, 1}, {2, -2}, {0, 0}]
    force = wall
      |> Tanx.Core.Obstacles.decompose_wall
      |> Tanx.Core.Obstacles.force_from_decomposed_wall({0.5, -1.0}, :math.sqrt(2))
    assert_structure_in_epsilon(force, {-0.5, -1.0})
  end


  test "intersection with triangle, first segment" do
    wall = [{-1, 0}, {1, 2}, {1, -1}]
    {intersection, _normal} = wall
      |> Tanx.Core.Obstacles.decompose_wall
      |> Tanx.Core.Obstacles.collision_with_decomposed_wall({-2, 0.5}, {2, 0.5})
    assert_structure_in_epsilon(intersection, {-0.5, 0.5})
  end


  test "intersection with triangle, second segment" do
    wall = [{-1, 0}, {1, 2}, {1, -1}]
    {intersection, _normal} = wall
      |> Tanx.Core.Obstacles.decompose_wall
      |> Tanx.Core.Obstacles.collision_with_decomposed_wall({2, 0.5}, {-2, 0.5})
    assert_structure_in_epsilon(intersection, {1, 0.5})
  end


  test "intersection with triangle, miss" do
    wall = [{-1, 0}, {1, 2}, {1, -1}]
    intersection = wall
      |> Tanx.Core.Obstacles.decompose_wall
      |> Tanx.Core.Obstacles.collision_with_decomposed_wall({2, 0.5}, {0, -3})
    assert intersection == nil
  end


  test "intersection with triangle, did not reach" do
    wall = [{-1, 0}, {1, 2}, {1, -1}]
    intersection = wall
      |> Tanx.Core.Obstacles.decompose_wall
      |> Tanx.Core.Obstacles.collision_with_decomposed_wall({2, 0.5}, {1.5, 0.5})
    assert intersection == nil
  end

end

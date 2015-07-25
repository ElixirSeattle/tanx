defmodule Tanx.Core.Obstacles do

  @moduledoc """
  The Obstacles module computes force on tanks due to obstacles.
  """


  @doc """
  Given a wall, returns a "decomposed" form of the wall that is preprocessed to
  make force computation efficient.

  The decomposed form is a list of tuples representing, in order, concave corners,
  convex corners, and segments, where
  * each concave_corner is {point1, dir0, dir1, dir2, t_ratio, s_ratio} where
    * point1 is the corner
    * dir0 is the direction unit vector toward the previous point
    * dir2 is the direction unit vector toward the next point
    * dir1 is the direction unit vector halfway between them
    * t_ratio is t/r where r is the radius and t is the dist along each side
    * s_ratio is s/r where s is the dist along bisect_dir to the final point
  * each convex_corner is {point0, point1, point2}
  * each segment is {point0, point1}
  """
  def decompose_wall(points = [p0, p1 | _]) do
    {concave, convex, segments} = (points ++ [p0, p1])
      |> Enum.chunk(3, 1)
      |> Enum.reduce({[], [], []}, &_decompose_wall_triplet/2)
    concave ++ convex ++ segments
  end
  def decompose_wall(_points), do: []


  defp _decompose_wall_triplet([p0, p1, p2], {concave, convex, segments}) do
    segments = [{p0, p1} | segments]
    if _cross_magnitude(p0, p1, p2) <= 0 do
      convex = [{vdiff(p1, p0) |> _left |> vadd(p1), p1, vdiff(p1, p2) |> _right |> vadd(p1)} | convex]
    else
      dir0 = vdiff(p0, p1) |> _normalize
      dir2 = vdiff(p2, p1) |> _normalize
      dir1 = vadd(dir0, dir2) |> _normalize
      dist0 = _dist(p0, p1)
      dist2 = _dist(p2, p1)
      csquared = _dist_squared(p2, p0)
      denom = csquared - (dist2 - dist0) * (dist2 - dist0)
      t_ratio = :math.sqrt(((dist0 + dist2) * (dist0 + dist2) - csquared) / denom)
      s_ratio = :math.sqrt(4.0 * dist0 * dist2 / denom)
      concave = [{p1, dir0, dir1, dir2, t_ratio, s_ratio} | concave]
    end
    {concave, convex, segments}
  end


  def force_from_decomposed_wall(decomposed_wall, p, radius) do
    force = decomposed_wall
      |> Enum.find_value(&(element_force(&1, p, radius)))
    if force == nil, do: {0.0, 0.0}, else: force
  end


  def force_from_decomposed_walls(decomposed_walls, p, radius) do
    decomposed_walls
      |> Enum.reduce({0.0, 0.0}, fn (wall, acc) ->
        force_from_decomposed_wall(wall, p, radius) |> vadd(acc)
      end)
  end


  def force_from_point(from, p, radius) do
    case force_from_point_internal(from, p, radius) do
      nil -> {0.0, 0.0}
      force -> force
    end
  end


  defp force_from_point_internal(from, p, radius) do
    normal = vdiff(p, from)
    dist = _norm(normal)
    if dist < radius do
      if dist == 0 do
        # TODO: Change to :rand once we're on Erlang 18
        ang = :random.uniform() * :math.pi() * 2
        {radius * :math.cos(ang), radius * :math.sin(ang)}
      else
        normal |> _scale((radius - dist) / dist)
      end
    else
      nil
    end
  end


  # Force for a wall segment
  defp element_force({p0, p1}, p, radius) do
    if _cross_magnitude(p0, p, p1) < 0 do
      a = vdiff(p, p0)
      b = vdiff(p1, p0)
      factor = vdot(a, b) / _norm_squared(b)
      if factor >= 0.0 and factor <= 1.0 do
        proj = _scale(b, factor) |> vadd(p0)
        force_from_point_internal(proj, p, radius)
      else
        nil
      end
    else
      nil
    end
  end

  # Force for a convex corner
  defp element_force({n0, p1, n2}, p, radius) do
    if _cross_magnitude(n0, p1, p) >= 0 && _cross_magnitude(p, p1, n2) >= 0 do
      force_from_point_internal(p1, p, radius)
    else
      nil
    end
  end

  # Force for a concave corner
  defp element_force({p1, dir0, dir1, dir2, t_ratio, s_ratio}, p, radius) do
    p0 = _scale(dir0, radius * t_ratio) |> vadd(p1)
    p2 = _scale(dir2, radius * t_ratio) |> vadd(p1)
    p3 = _scale(dir1, radius * s_ratio) |> vadd(p1)
    if _cross_magnitude(p, p0, p1) >= 0 && _cross_magnitude(p, p1, p2) >= 0 &&
        _cross_magnitude(p, p2, p3) >= 0 && _cross_magnitude(p, p3, p0) >= 0 do
      vdiff(p3, p)
    else
      nil
    end
  end


  defp vadd({x0, y0}, {x1, y1}), do: {x0 + x1, y0 + y1}

  defp vdiff({x0, y0}, {x1, y1}), do: {x0 - x1, y0 - y1}

  defp vdot({x0, y0}, {x1, y1}), do: x0 * x1 + y0 * y1

  defp _right({x, y}), do: {y, -x}

  defp _left({x, y}), do: {-y, x}

  defp _cross_magnitude({x0, y0}, {x1, y1}, {x2, y2}) do
    (x1 - x0) * (y2 - y1) - (x2 - x1) * (y1 - y0)
  end

  defp _scale({x, y}, r), do: {x * r, y * r}

  defp _norm_squared({x, y}), do: x * x + y * y

  defp _norm(p), do: p |> _norm_squared |> :math.sqrt

  defp _dist_squared(p0, p1), do: vdiff(p0, p1) |> _norm_squared

  defp _dist(p0, p1), do: _dist_squared(p0, p1) |> :math.sqrt

  defp _normalize(p), do: _scale(p, 1 / _norm(p))

end

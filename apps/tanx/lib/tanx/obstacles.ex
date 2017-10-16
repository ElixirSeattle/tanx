defmodule Tanx.Obstacles do

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
      |> Enum.reduce({[], [], []}, &decompose_wall_triplet/2)
    {concave ++ convex ++ segments, segments}
  end
  def decompose_wall(_points), do: {[], []}


  @doc """
  Given a decomposed wall, and an object represented by a point and radius,
  returns the force applied by the wall against the object.
  """
  def force_from_decomposed_wall({elements, _segments}, p, radius) do
    force = elements
      |> Enum.map(&(element_force(&1, p, radius)))
      |> Enum.max_by(fn
        nil -> 0.0
        {x, y} -> x * x + y * y
      end)
    if force == nil, do: {0.0, 0.0}, else: force
  end


  @doc """
  Given a list of decomposed walls, and an object represented by a point and radius,
  returns the total force applied by all walls against the object.
  """
  def force_from_decomposed_walls(decomposed_walls, p, radius) do
    decomposed_walls
      |> Enum.reduce({0.0, 0.0}, fn (wall, acc) ->
        force_from_decomposed_wall(wall, p, radius) |> vadd(acc)
      end)
  end


  @doc """
  Given a fixed point, and an object represented by a point and radius,
  returns the force applied by the fixed point against the object.
  """
  def force_from_point(from, p, radius) do
    case force_from_point_internal(from, p, radius) do
      nil -> {0.0, 0.0}
      force -> force
    end
  end


  @doc """
  Given a single decomposed wall, and two points representing two locations of a
  point object, returns either a tuple of {point of impact on the wall, normal to
  the wall}, or nil for no impact.
  """
  def collision_with_decomposed_wall(decomposed_wall, from, to) do
    decomposed_wall
      |> wall_collision_as_ratio_and_normal(from, to)
      |> ratio_to_point(from, to)
  end


  @doc """
  Given a list of decomposed walls, and two points representing two locations of a
  point object, returns either a tuple of {the first point of impact on a wall, the
  normal to the wall}, or nil for no impact.
  """
  def collision_with_decomposed_walls(decomposed_walls, from, to) do
    decomposed_walls
      |> Enum.map(&(wall_collision_as_ratio_and_normal(&1, from, to)))
      |> min_ratio_or_nil
      |> ratio_to_point(from, to)
  end


  defp ratio_to_point(nil, _from, _to), do: nil
  defp ratio_to_point({ratio, normal}, from, to) do
    {vdiff(to, from) |> vscale(ratio) |> vadd(from), normal}
  end


  defp min_ratio_or_nil(values) do
    values |> Enum.min_by(fn
      nil -> 2.0
      {ratio, _normal} -> ratio
    end)
  end


  defp wall_collision_as_ratio_and_normal({_elements, segments}, from, to) do
    segments
      |> Enum.map(&(segment_intersection_as_ratio_and_normal(&1, from, to)))
      |> min_ratio_or_nil
  end


  defp segment_intersection_as_ratio_and_normal({p0, p1}, from, to) do
    from_mag = cross_magnitude(p0, from, p1)
    to_mag = cross_magnitude(p0, to, p1)
    if from_mag < 0 and to_mag >= 0 and
        cross_magnitude(from, p0, to) >= 0 and cross_magnitude(from, p1, to) <= 0 do
      normal = vdiff(p1, p0) |> turn_left |> normalize
      {from_mag / (from_mag - to_mag), normal}
    else
      nil
    end
  end


  defp decompose_wall_triplet([p0, p1, p2], {concave, convex, segments}) do
    segments = [{p0, p1} | segments]
    if cross_magnitude(p0, p1, p2) <= 0 do
      elem = {vdiff(p1, p0) |> turn_left |> vadd(p1), p1, vdiff(p1, p2) |> turn_right |> vadd(p1)}
      convex = [elem | convex]
      {concave, convex, segments}
    else
      dir0 = vdiff(p0, p1) |> normalize
      dir2 = vdiff(p2, p1) |> normalize
      dir1 = vadd(dir0, dir2) |> normalize
      dist0 = vdist(p0, p1)
      dist2 = vdist(p2, p1)
      csquared = dist_squared(p2, p0)
      denom = csquared - (dist2 - dist0) * (dist2 - dist0)
      t_ratio = :math.sqrt(((dist0 + dist2) * (dist0 + dist2) - csquared) / denom)
      s_ratio = :math.sqrt(4.0 * dist0 * dist2 / denom)
      concave = [{p1, dir0, dir1, dir2, t_ratio, s_ratio} | concave]
      {concave, convex, segments}
    end
  end


  defp force_from_point_internal(from, p, radius) do
    normal = vdiff(p, from)
    dist = vnorm(normal)
    if dist < radius do
      if dist == 0 do
        ang = :rand.uniform() * :math.pi() * 2
        {radius * :math.cos(ang), radius * :math.sin(ang)}
      else
        normal |> vscale((radius - dist) / dist)
      end
    else
      nil
    end
  end


  # Force for a wall segment
  defp element_force({p0, p1}, p, radius) do
    if cross_magnitude(p0, p, p1) < 0 do
      a = vdiff(p, p0)
      b = vdiff(p1, p0)
      factor = vdot(a, b) / norm_squared(b)
      if factor >= 0.0 and factor <= 1.0 do
        proj = vscale(b, factor) |> vadd(p0)
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
    if cross_magnitude(n0, p1, p) >= 0 and cross_magnitude(p, p1, n2) >= 0 do
      force_from_point_internal(p1, p, radius)
    else
      nil
    end
  end

  # Force for a concave corner
  defp element_force({p1, dir0, dir1, dir2, t_ratio, s_ratio}, p, radius) do
    p0 = vscale(dir0, radius * t_ratio) |> vadd(p1)
    p2 = vscale(dir2, radius * t_ratio) |> vadd(p1)
    p3 = vscale(dir1, radius * s_ratio) |> vadd(p1)
    if cross_magnitude(p, p0, p1) >= 0 and cross_magnitude(p, p1, p2) >= 0 and
        cross_magnitude(p, p2, p3) >= 0 and cross_magnitude(p, p3, p0) >= 0 do
      vdiff(p3, p)
    else
      nil
    end
  end


  defp vadd({x0, y0}, {x1, y1}), do: {x0 + x1, y0 + y1}

  defp vdiff({x0, y0}, {x1, y1}), do: {x0 - x1, y0 - y1}

  defp vdot({x0, y0}, {x1, y1}), do: x0 * x1 + y0 * y1

  defp turn_right({x, y}), do: {y, -x}

  defp turn_left({x, y}), do: {-y, x}

  defp cross_magnitude({x0, y0}, {x1, y1}, {x2, y2}) do
    (x1 - x0) * (y2 - y1) - (x2 - x1) * (y1 - y0)
  end

  defp vscale({x, y}, r), do: {x * r, y * r}

  defp norm_squared({x, y}), do: x * x + y * y

  defp vnorm(p), do: p |> norm_squared |> :math.sqrt

  defp dist_squared(p0, p1), do: vdiff(p0, p1) |> norm_squared

  defp vdist(p0, p1), do: dist_squared(p0, p1) |> :math.sqrt

  defp normalize(p), do: vscale(p, 1 / vnorm(p))

end

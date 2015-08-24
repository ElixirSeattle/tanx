const MAX_CANVAS_WIDTH = 600;
const MAX_CANVAS_HEIGHT = 600;


class ArenaStructure {

  constructor(structure) {
    this._structure = structure;

    let xScale = MAX_CANVAS_WIDTH / structure.width;
    let yScale = MAX_CANVAS_HEIGHT / structure.height;
    this._scaleFactor = xScale < yScale ? xScale : yScale;
    this._width = this._scaleFactor * structure.width;
    this._height = this._scaleFactor * structure.height;
  }


  scaleFactor() {
    return this._scaleFactor;
  }


  width() {
    return this._width;
  }


  height() {
    return this._height;
  }


  walls() {
    return this._structure.walls;
  }


  entryPoints() {
    return this._structure.entry_points;
  }


  entryPointRadius() {
    return this._structure.entry_point_radius;
  }


  findEntryPoint(x, y) {
    let dist = this.entryPointRadius() * this.scaleFactor();
    let distSquared = dist * dist;
    let found = null;
    this.entryPoints().forEach(ep => {
      let point = this.onScreenPoint(ep.x, ep.y);
      if ((x - point.x) * (x - point.x) + (y - point.y) * (y - point.y) <= distSquared) {
        found = ep;
      }
    });
    return found;
  }


  onScreenPoint(x, y) {
    let xOffset = this._width / 2;
    let yOffset = this._height / 2;

    let screenX = xOffset + (x * this.scaleFactor());
    let screenY = yOffset - (y * this.scaleFactor());
    return {x: screenX, y: screenY};
  }


  onScreenRect(x, y, width, height) {
    let screenPoint = this.onScreenPoint(x, y);
    let screenWidth = width * this.scaleFactor();
    let screenHeight = height * this.scaleFactor();
    return {x: screenPoint.x, y: screenPoint.y, width: screenWidth, height: screenHeight};
  }

}


export default ArenaStructure;

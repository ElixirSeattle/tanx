const WINDOW_HEIGHT_ADJUST = 100;


class ArenaStructure {

  constructor(structure) {
    this._structure = structure;
    this.recomputeScale();
    $(window).on('resize', event => {
      this.recomputeScale();
    });
  }


  recomputeScale() {
    let maxWidth = $('#tanx-arena-container').innerWidth();
    let maxHeight = $(window).innerHeight() - WINDOW_HEIGHT_ADJUST;
    let xScale = maxWidth / this._structure.w;
    let yScale = maxHeight / this._structure.h;
    let scale = xScale < yScale ? xScale : yScale;
    this._width = scale * this._structure.w;
    this._height = scale * this._structure.h;
    this._scaleFactor = scale * 0.99;
    $('#tanx-canvas')
      .css({width: this._width + 'px', height: this._height + 'px'})
      .attr({width: this._width, height: this._height});
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
    return this._structure.wa;
  }


  entryPoints() {
    return this._structure.ep;
  }


  entryPointRadius() {
    return this._structure.epr;
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

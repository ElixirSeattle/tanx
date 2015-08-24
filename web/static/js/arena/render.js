
class ArenaRender {

  constructor(arenaStructure) {
    this._tankSprite = new Image();
    this._tankSprite.src = 'images/tank_sprite.png';
    this._canvas = $('#tanx-canvas');
    this._explosionSound = new Audio("sounds/Explosion3.wav");
    this._backgroundMusic = $('#background-music')[0];
    this._arenaStructure = arenaStructure;

    this._canvas.attr({
      width: this._arenaStructure.width(),
      height: this._arenaStructure.height()
    });
  }


  render(objects) {
    let hasTank = objects.tanks.some(tank => tank.is_me);
    let context = this._canvas.get(0).getContext("2d");

    // Clear the canvas
    context.clearRect(0, 0, this._arenaStructure.width(), this._arenaStructure.height());

    // Draw maze walls
    this._arenaStructure.walls().forEach(wall => {
      this._renderWall(context, wall);
    });

    // Draw entry points
    this._arenaStructure.entryPoints().forEach(ep => {
      this._renderEntryPoint(context, ep, objects.entry_points_available[ep.name],
          this._arenaStructure.entryPointRadius());
    });

    // Draw tanks
    objects.tanks.forEach(tank => {
      this._renderTank(context, tank);
    });

    // Draw missiles
    objects.missiles.forEach(missile => {
      this._renderMissile(context, missile);
    });

    // Draw explosions
    objects.explosions.forEach(explosion => {
      this._renderExplosion(context, explosion);
    });

    // Start background music
    this._backgroundMusic.play();
  }


  _renderWall(context, wall) {
    context.save();
    context.strokeStyle = '#934b36';
    context.beginPath();
    let point = this._arenaStructure.onScreenPoint(wall[0], wall[1]);
    context.moveTo(point.x, point.y);
    for (let i=2; i<wall.length; i += 2) {
      point = this._arenaStructure.onScreenPoint(wall[i], wall[i+1]);
      context.lineTo(point.x, point.y);
      context.lineWidth = 3;
    }
    context.closePath();
    context.stroke();
    context.restore();
  }


  _renderEntryPoint(context, entryPoint, isAvailable, entry_point_radius) {
    context.save();

    let point = this._arenaStructure.onScreenPoint(entryPoint.x, entryPoint.y);
    let radius = entry_point_radius * this._arenaStructure.scaleFactor();
    let time = Date.now() % 1000;
    if (time < 500) {
      radius = radius * time / 500;
    } else {
      radius = radius * (1000 - time) / 500;
    }
    context.beginPath();
    context.strokeStyle = isAvailable ? '#ff0' : '#bb8';
    context.arc(point.x, point.y, radius, 0, Math.PI*2, false);
    context.stroke();

    context.restore();
  }


  _renderTank(context, tank) {
    context.save();

    let tankRect = this._arenaStructure.onScreenRect(tank.x, tank.y, tank.radius*2, tank.radius*2);
    context.translate(tankRect.x, tankRect.y);
    let screenRadius = Math.ceil(this._arenaStructure.scaleFactor() * 0.5);

    // Add names above enemies
    if (!tank.is_me) {
      context.textAlign = "center";
      context.font = '12px sans-serif';
      context.fillText(tank.name, 0, -this._arenaStructure.scaleFactor() * 0.7);
    }

    // Add armor indicator below all tanks
    let ratio = tank.armor / tank.max_armor;
    let red = 255;
    let green = 255;
    if (ratio < 0.5) {
      green = Math.floor(510 * ratio);
    } else {
      red = Math.floor(510 - 510 * ratio);
    }
    context.fillStyle = 'rgb(' + red + ',' + green + ',0)';
    context.fillRect(-screenRadius, screenRadius * 1.2, 2 * screenRadius * ratio, 4);
    context.strokeStyle = '#fff';
    context.strokeRect(-screenRadius, screenRadius * 1.2, 2 * screenRadius, 4);


    let rotateTankImage90Degrees = 90 * Math.PI/180;
    context.rotate(-tank.heading + rotateTankImage90Degrees);

    let spriteSheetX = 92;
    let spriteSheetY = tank.is_me ? 1 : 84;
    context.drawImage(this._tankSprite, spriteSheetX, spriteSheetY, 67, 79,
      -screenRadius, -screenRadius, screenRadius * 2, screenRadius * 2);

      context.restore();
  }

  _renderMissile(context, missile) {
    context.save();

    let missileRect = this._arenaStructure.onScreenRect(missile.x, missile.y, 0.2, 0.2);
    context.translate(missileRect.x, missileRect.y);

    context.rotate(-missile.heading);

    let spriteSheetX = 455;
    let spriteSheetY = 168;
    let onScreenWidth = 40;
    let onScreenHeight = 40;
    context.drawImage(this._tankSprite, spriteSheetX, spriteSheetY, 67, 79,
      0, -onScreenHeight/2, onScreenWidth, onScreenHeight);

    context.restore();
  }


  _renderExplosion(context, explosion) {
    context.save();

    let point = this._arenaStructure.onScreenPoint(explosion.x, explosion.y);
    let radius = explosion.radius * this._arenaStructure.scaleFactor();
    if (explosion.age < 0.5) {
      radius = radius * explosion.age * 2.0;
    }
    context.beginPath();
    context.fillStyle = "#fa4";
    context.arc(point.x, point.y, radius, 0, Math.PI*2, false);
    context.fill();
    if (explosion.age > 0.5) {
      radius = explosion.radius * this._arenaStructure.scaleFactor() * (explosion.age - 0.5) * 2.0;
      context.beginPath();
      context.fillStyle = "#fff";
      context.arc(point.x, point.y, radius, 0, Math.PI*2, false);
      context.fill();
    }

    if (explosion.age < .07) {
      this._explosionSound.play();
    }

    context.restore();
  }

}


export default ArenaRender;

const Jimp = require('jimp');
const path = require('path');

async function createRoundedLogo() {
  const inputPath = path.join(process.cwd(), 'assets', 'images', 'delira_logo.png');
  const outputPath = path.join(process.cwd(), 'assets', 'images', 'rounded_logo.png');

  try {
    const image = await Jimp.read(inputPath);
    const size = Math.min(image.bitmap.width, image.bitmap.height);
    
    // Resize to a standard square if not already
    image.cover(size, size);

    // Create a mask for rounded corners
    // BorderRadius 28 in a 120 container is 28/120 = 0.233 of the size.
    // For a 512px icon, that's ~120px radius.
    const radius = Math.floor(size * (28 / 120));

    // Jimp's mask or circle is not exactly "rounded rect"
    // But we can manually process pixels or use a workaround.
    // Actually, Jimp has .mask() but creating the mask is hard.
    // Simpler: use .circle() if they want a circle, but they want "rounded" (squircle-like).
    
    // Let's use a simpler approach: 
    // Since I can't easily draw a rounded rect in Jimp without an external mask,
    // I'll try to use a more powerful tool if available, or just use a circle for now as a placeholder 
    // IF the user is okay with it. But they wanted "rounded gitu" (like the 28 radius).
    
    // Actually, I can just use a CSS-like formula to mask.
    image.scan(0, 0, image.bitmap.width, image.bitmap.height, function(x, y, idx) {
      const w = image.bitmap.width;
      const h = image.bitmap.height;
      const r = radius;
      
      let inside = true;
      if (x < r && y < r) { // Top-left
        if (Math.pow(x - r, 2) + Math.pow(y - r, 2) > Math.pow(r, 2)) inside = false;
      } else if (x > w - r && y < r) { // Top-right
        if (Math.pow(x - (w - r), 2) + Math.pow(y - r, 2) > Math.pow(r, 2)) inside = false;
      } else if (x < r && y > h - r) { // Bottom-left
        if (Math.pow(x - r, 2) + Math.pow(y - (h - r), 2) > Math.pow(r, 2)) inside = false;
      } else if (x > w - r && y > h - r) { // Bottom-right
        if (Math.pow(x - (w - r), 2) + Math.pow(y - (h - r), 2) > Math.pow(r, 2)) inside = false;
      }

      if (!inside) {
        this.bitmap.data[idx + 3] = 0; // Set alpha to 0
      }
    });

    await image.writeAsync(outputPath);
    console.log('Successfully created rounded_logo.png');
  } catch (err) {
    console.error('Error processing image:', err);
    process.exit(1);
  }
}

createRoundedLogo();

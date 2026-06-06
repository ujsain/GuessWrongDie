-- All behavioural tunables for the shoot effect in one place.
-- (The bullet's LOOK now lives on the Bullet.DuelBullet template part.)
local Config = {}

-- Animation
Config.SHOOT_ANIM_ID = "rbxassetid://136695495090944"
Config.FIRE_MOMENT   = 0.3   -- fraction through the clip the gun "fires"

-- Bullet movement
Config.BULLET_SPEED     = 20  -- studs / second
Config.BULLET_MAX_RANGE = 9  -- straight-shot range if it hits nothing

-- Impact dust puffs
Config.DUST_COLOR = Color3.fromRGB(120, 110, 95)

-- Deflect bounce
Config.DEFLECT_FORWARD_DISTANCE = 4.5  -- studs forward before it bounces back

-- Both-shoot collision (bullets meet near center, then drop)
Config.COLLIDE_MEET_FRACTION = 0.48  -- how far toward the opponent muzzle each slug stops
Config.COLLIDE_DROP_DISTANCE = 3     -- studs the dead slug falls
Config.COLLIDE_DROP_TIME     = 0.45  -- seconds for the fall + fade

return Config

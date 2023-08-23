-- ========== GENERATED BY ParticleSystemPreset Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('ParticleSystemPreset', {
	game_time_animated = true,
	group = "Grenade_TearGas",
	id = "TearGas_Grenade_Spray",
	stable_cam_distance = true,
	PlaceObj('ParticleEmitter', {
		'label', "Smoke",
		'world_space', true,
		'emit_detail_level', 100,
		'max_live_count', 100,
		'parts_per_sec', 800,
		'lifetime_min', 2000,
		'lifetime_max', 4000,
		'texture', "Textures/Particles/mist.tga",
		'normalmap', "Textures/Particles/mist.norm.tga",
		'frames', point(2, 2),
		'far_softness', 100,
		'drawing_order', 1,
		'outlines', {
			{
				point(32, 32),
				point(32, 2016),
				point(2016, 2016),
				point(2016, 32),
			},
			{
				point(2080, 2016),
				point(3968, 2016),
				point(4064, 32),
				point(2080, 32),
			},
			{
				point(32, 4032),
				point(2016, 4032),
				point(2016, 2080),
				point(32, 2080),
			},
			{
				point(2080, 4032),
				point(4064, 4032),
				point(4064, 2080),
				point(2080, 2080),
			},
		},
		'texture_hash', 6609993512092536490,
	}, nil, nil),
	PlaceObj('ParticleBehaviorPickFrame', nil, nil, nil),
	PlaceObj('ParticleBehaviorGravityWind', nil, nil, nil),
	PlaceObj('ParticleBehaviorFriction', {
		'friction', {
			range_y = 10,
			scale = 1000,
			point(0, 1019, 1019),
			point(333, 900, 900),
			point(667, 900, 900),
			point(1000, 900, 900),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorRandomSpeedSpray', {
		'direction', point(0, 1000, 0),
		'spread_angle', 2000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFadeInOut', {
		'fade_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 0, 0),
			point(20, 515, 515),
			point(479, 249, 249),
			point(1000, 0, 0),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorResizeCurve', {
		'max_size', 3000,
		'size_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 105, 105),
			point(354, 410, 410),
			point(646, 677, 677),
			point(1000, 1000, 1000),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorColorize', {
		'start_color_min', RGBA(182, 204, 193, 255),
		'start_color_max', RGBA(160, 179, 169, 255),
		'mid_color', RGBA(130, 153, 140, 255),
		'end_color', RGBA(106, 153, 128, 255),
	}, nil, nil),
	PlaceObj('ParticleBehaviorWind', nil, nil, nil),
})


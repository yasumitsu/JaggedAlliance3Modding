-- ========== GENERATED BY ParticleSystemPreset Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('ParticleSystemPreset', {
	group = "Shooting",
	id = "Knife_Trail",
	ignore_game_object_age = true,
	particles_scale_with_object = true,
	PlaceObj('ParticleEmitter', {
		'label', "Distort",
		'bins', set( "E" ),
		'world_space', true,
		'emit_detail_level', 100,
		'max_live_count', 100,
		'parts_per_sec', 0,
		'parts_per_meter', 600,
		'lifetime_min', 250,
		'lifetime_max', 250,
		'angle', range(0, 360),
		'size_min', 400,
		'size_max', 400,
		'shader', "Distortion",
		'texture', "Textures/Particles/mist.tga",
		'normalmap', "Textures/Particles/clouds_2x2.norm.tga",
		'frames', point(2, 2),
		'light_softness', 1000,
		'flow_speed', 9,
		'flow_scale', 83,
		'softness', 100,
		'distortion_scale', -10,
		'distortion_scale_max', 10,
		'outlines', {
			{
				point(64, 0),
				point(64, 2016),
				point(2016, 2016),
				point(2016, 0),
			},
			{
				point(2048, 0),
				point(2048, 2016),
				point(4064, 2016),
				point(4064, 0),
			},
			{
				point(0, 4032),
				point(2016, 4032),
				point(2016, 2048),
				point(0, 2048),
			},
			{
				point(2048, 4032),
				point(4064, 4032),
				point(4064, 2048),
				point(2048, 2048),
			},
		},
		'texture_hash', 6609993512092536490,
	}, nil, nil),
	PlaceObj('ParticleBehaviorPickFrame', {
		'bins', set( "E" ),
	}, nil, nil),
	PlaceObj('ParticleBehaviorFadeInOut', {
		'bins', set( "E" ),
		'fade_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 0, 0),
			point(36, 1000, 1000),
			point(785, 1000, 1000),
			point(1000, 0, 0),
		},
	}, nil, nil),
})


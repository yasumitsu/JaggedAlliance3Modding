-- ========== GENERATED BY XTemplate Editor (Alt-F3) DO NOT EDIT MANUALLY! ==========

PlaceObj('XTemplate', {
	__is_kind_of = "XWindow",
	group = "BobbyRayGunsShop",
	id = "PDABrowserBobbyRay_StoreEntry_Stats",
	PlaceObj('XTemplateWindow', {
		'IdNode', true,
		'Padding', box(5, 5, 5, 5),
		'LayoutMethod', "VList",
		'MouseCursor', "UI/Cursors/Pda_Cursor.tga",
	}, {
		PlaceObj('XTemplateForEach', {
			'array', function (parent, context) return context:GetShopStats() end,
			'item_in_context', "stat",
			'run_after', function (child, context, item, i, n, last)
				child.idStatName:SetText(item[1])
				child.idValue:SetText(item[2])
			end,
		}, {
			PlaceObj('XTemplateWindow', {
				'IdNode', true,
				'GridStretchX', false,
				'GridStretchY', false,
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'Id', "idStatName",
					'Padding', box(0, 0, 0, 0),
					'Dock', "left",
					'TextStyle', "PDABobbyStore_HG16D",
					'Translate', true,
				}),
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'Id', "idValue",
					'Padding', box(0, 0, 0, 0),
					'Dock', "right",
					'TextStyle', "PDABobbyStore_HG16F",
					'Translate', true,
					'WordWrap', false,
					'Shorten', true,
				}),
				}),
			}),
		PlaceObj('XTemplateWindow', {
			'__condition', function (parent, context)
				local stats = context:GetShopStats()
				return not stats or stats == {}
			end,
			'__class', "XText",
			'Dock', "box",
			'TextStyle', "PDABobbyStore_HG18D_Transparent",
			'Translate', true,
			'Text', T(305343214371, --[[XTemplate PDABrowserBobbyRay_StoreEntry_Stats Text]] "N/A"),
			'TextHAlign', "center",
			'TextVAlign', "center",
		}),
		}),
})


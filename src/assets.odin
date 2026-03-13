package hexes

load_assets :: proc() {
	game.assets = Assets {
		font = load_font("./data/fonts/alagard.png"),
	}
}

unload_assets :: proc() {
	unload_font(game.assets.font)
}

get_font :: proc() -> Font {
	return game.assets.font
}

Assets :: struct {
	font: Font,
}

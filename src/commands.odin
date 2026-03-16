package hexes

process_command :: proc(command: string) {
  switch command {
  case "help":
    add_message("no one is coming to save you..")
  }
}

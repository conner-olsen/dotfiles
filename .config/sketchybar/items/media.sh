media=(
  icon=􀑪
  script="$PLUGIN_DIR/media.sh"
  label.max_chars=15
  scroll_texts=on
  updates=on
  padding_left=350  # Add padding to the left
)

sketchybar --add item media center \
           --set media "${media[@]}" \
           --subscribe media media_change
class_name ShopPanel
extends HubPanel
## Shop tab: the free basic kit (one free basic item per slot, so a player who lost everything can
## always gear up) and today's wares, refreshed after every run. Bought items go to the stash.

const CARD_SIZE := Vector2(330, 230)

var _basic_row: HBoxContainer
var _stock_row: HBoxContainer


func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	column.add_child(heading("Free basic kit  ·  one per slot, can't be sold"))
	_basic_row = HBoxContainer.new()
	_basic_row.add_theme_constant_override("separation", 16)
	column.add_child(_basic_row)
	column.add_child(Control.new())
	column.add_child(heading("Today's wares  ·  new ones after every run"))
	_stock_row = HBoxContainer.new()
	_stock_row.add_theme_constant_override("separation", 16)
	column.add_child(_stock_row)
	column.add_child(Control.new())
	column.add_child(UiKit.wrapped("A free item is equipped right away if its slot is empty. Items you buy go to your stash; selling one returns a quarter of its price.", 15, DIM_COLOR))


func refresh() -> void:
	UiKit.clear(_basic_row)
	for slot in Item.SLOTS:
		_basic_row.add_child(_free_offer(slot))
	UiKit.clear(_stock_row)
	if Profile.shop_stock.is_empty():
		_stock_row.add_child(UiKit.label("Sold out for today. New wares arrive after a run.", 16, DIM_COLOR))
	for item in Profile.shop_stock:
		_stock_row.add_child(_offer(item))


func _offer(item: Item) -> Control:
	var affordable := Profile.gold >= item.price()
	var buy := UiKit.icon_button("Buy  %d" % item.price(), "two-coins", UiTheme.Kind.SECONDARY, 16, UiTheme.GOLD_COIN)
	buy.disabled = not affordable
	buy.tooltip_text = "" if affordable else "You need %d more gold" % (item.price() - Profile.gold)
	buy.pressed.connect(Profile.buy.bind(item))
	buy.pressed.connect(func() -> void: Audio.play("gold"))
	return _card(item, buy)


## A free basic item; it can be taken only if you don't already have the free one for that slot.
func _free_offer(slot: String) -> Control:
	var owned := Profile.has_free_basic(slot)
	var take := UiKit.button("You have one" if owned else "Take  ·  free", UiTheme.Kind.SECONDARY, 16, UiTheme.GOOD)
	take.disabled = owned
	take.pressed.connect(Profile.take_free_basic.bind(slot))
	take.pressed.connect(func() -> void: Audio.play("equip"))
	return _card(ItemGenerator.free_basic(slot), take)


## Item card on a plate trimmed in its rarity color, with its button underneath.
func _card(item: Item, button: Button) -> PanelContainer:
	var panel := UiKit.plate(item.color(), 14.0, item.rarity >= Item.Rarity.RARE)
	panel.custom_minimum_size = CARD_SIZE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var card := UiKit.item_card(item, 56.0)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(card)
	column.add_child(button)
	return panel

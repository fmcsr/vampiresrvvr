class_name ShopPanel
extends HubPanel
## Shop tab: basic items are always in stock (so a player who lost everything can still gear up);
## today's wares are refreshed after every run. Bought items go to the stash.

const CARD_SIZE := Vector2(300, 200)

var _basic_row: HBoxContainer
var _stock_row: HBoxContainer


func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	column.add_child(heading("BASIC ITEMS — always in stock"))
	_basic_row = HBoxContainer.new()
	_basic_row.add_theme_constant_override("separation", 16)
	column.add_child(_basic_row)
	column.add_child(Control.new())
	column.add_child(heading("TODAY'S WARES — refreshed after every run"))
	_stock_row = HBoxContainer.new()
	_stock_row.add_theme_constant_override("separation", 16)
	column.add_child(_stock_row)
	column.add_child(Control.new())
	column.add_child(UiKit.label("Items you buy go to your stash; equip them in the Equipment tab. Selling an item from your stash returns a quarter of its price.", 15, DIM_COLOR))


func refresh() -> void:
	UiKit.clear(_basic_row)
	for slot in Item.SLOTS:
		_basic_row.add_child(_offer(ItemGenerator.basic(slot)))
	UiKit.clear(_stock_row)
	if Profile.shop_stock.is_empty():
		_stock_row.add_child(UiKit.label("Sold out for today. New wares arrive after a run.", 16, DIM_COLOR))
	for item in Profile.shop_stock:
		_stock_row.add_child(_offer(item))


func _offer(item: Item) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	panel.add_theme_stylebox_override("panel", card_style(item.color()))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var card := UiKit.item_card(item)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(card)
	var buy := UiKit.button("Buy — %d gold" % item.price(), GOLD_COLOR, 15)
	buy.disabled = Profile.gold < item.price()
	buy.pressed.connect(Profile.buy.bind(item))
	column.add_child(buy)
	return panel

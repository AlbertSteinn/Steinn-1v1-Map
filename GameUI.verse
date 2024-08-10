using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Fortnite.com/FortPlayerUtilities }
using { /Fortnite.com/UI }
using { /Verse.org/Colors }
using { /Verse.org/Colors/NamedColors }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { GameManagerModule }

GameUIModule := module:
    log_ui := class(log_channel){}

    # Contains different health style
    health_type := enum:
        Shield
        Health

    AllShields:health_type =  health_type.Shield
    BalancedHealth:health_type =  health_type.Health

    # Manages players' health
    healthmanager<public> := class:
        var HealthType<private>:health_type = health_type.Shield
        var TotalHealth<private>:float = 184.5

        SetHealth(Health:float):void =
            set TotalHealth = Health

        SetHealthType(Type:health_type):void =
            set HealthType = Type

        # Changes all players health
        ChangeHealth(Players:[]player):void = 
            for:
                Player:Players
                FortCharacter := Player.GetFortCharacter[]
            do:
                if(HealthType = AllShields):
                    FortCharacter.SetMaxHealth(1.0)
                    FortCharacter.SetMaxShield(TotalHealth - 1.0)
                else:
                    FortCharacter.SetMaxHealth(100.0)
                    FortCharacter.SetMaxShield(TotalHealth - 100.0)
                    Print("Balanced")

    ui_list_node := class<unique>:
        var Next:?ui_list_node = false
        var Previous:?ui_list_node = false
        CurrentUI:canvas = canvas{}

    # Manages the main menu order
    ui_linked_list := class:
        # Main Menu
        Head:ui_list_node
        # The current Page the player is on
        var CurrentNode:ui_list_node := ui_list_node{}

        TraverseList()<transacts>:void =
            if(Current := CurrentNode.Next?):
                set CurrentNode = Current

        BacktrackList()<transacts>:void =
            if(Current := CurrentNode.Previous?):
                set CurrentNode = Current

        # Adds a new Node to list and sets CurrentNode to it
        Advance(Node:ui_list_node)<transacts>:void =
            set Node.Previous = option{CurrentNode}
            set CurrentNode.Next = option{Node}
            TraverseList()
        
        # Removes CurrentNode and sets it to previous Node
        Recede()<transacts>:void =
            BacktrackList()
            set CurrentNode.Next = false

    # Constructor for UI Linked List
    CreateUIList<constructor>(Node:ui_list_node)<transacts>:=
        ui_linked_list:
            Head := Node
            CurrentNode := Node

    Speed := struct<concrete>:
        @editable
        SpeedType:string = ""
        @editable
        Speeds:[]string = array{}

    ColorBlock := struct<concrete>:
        @editable
        Color:string = "0077BE80"
        @editable
        Opacity:type{x:float where x >= 0.0, x <= 1.0} = 0.9
        @editable
        Size:vector2 = vector2{X := 800.0, Y := 1080.0}

    Game_UI_Manager<public> := class(creative_device):
        Logger:log = log{Channel:=log_ui}

        @editable
        SpawnPads:[]player_spawner_device = array{}
        @editable 
        MenuButton:button_device = button_device{}
        @editable 
        Endgame:end_game_device = end_game_device{}
        @editable
        SpectatorManager:class_and_team_selector_device = class_and_team_selector_device{}
        @editable
        SlowSpeedMessage:[]elimination_feed_device = array{}
        @editable
        NormalSpeedMessage:elimination_feed_device = elimination_feed_device{}
        @editable
        FastSpeedMessage:[]elimination_feed_device = array{}
        @editable
        SlowCinematics:[]cinematic_sequence_device = array{}
        @editable
        NormalCinematics:cinematic_sequence_device = cinematic_sequence_device{}
        @editable
        FastCinematics:[]cinematic_sequence_device = array{}
        @editable
        MapSpeeds:[]Speed = array:
            Speed{SpeedType:="Slow"}, Speed{SpeedType:="Normal"}, Speed{SpeedType:="Fast"}, Speed{SpeedType:="Back"}
        @editable
        MenuColor:ColorBlock = ColorBlock{}

        # Button texts for the Main Menu Buttons
        MenuButtonNames:[]string = array:
            "Map Speed", "Health", "Spectate", "Restart", "Cancel"
        # Array of Max healths allowed in game
        MaxHealths:[]float = array{184.5, 200.0}
        Anchor:anchors = anchors{Minimum := vector2{X := 0.4, Y := 0.2}, Maximum := vector2{X := 0.4, Y := 0.2}}
        HUDElements:[]hud_element_identifier = array:
            player_hud_identifier_all{}
            creative_hud_identifier_all{}
            hud_identifier_world_resource_wood{}
            hud_identifier_world_resource_stone{}
            hud_identifier_world_resource_metal{}
            hud_identifier_world_resource_permanite{}
            hud_identifier_world_resource_gold_currency{}
            hud_identifier_world_resource_ingredient{}

        # Arrays of interactable UI Buttons
        var MainMenuButtons:[player][]button_regular = map{}
        var MapSpeedButtons:[player][]button_regular = map{}
        var HealthButtons:[player][]button_regular = map{}
        var RestartButtons:[player][]button_regular = map{}
        var SpectateButtons:[player][]button_regular = map{}
        var AllShieldsButtons:[player][]button_regular = map{}
        var BalancedHealthButtons:[player][]button_regular = map{}
        var CustomHealthButtons:[player][]button_regular = map{}
        var SlowSpeedButtons:[player][]button_regular = map{}
        var FastSpeedButtons:[player][]button_regular = map{}

        var CustomHealthSliders:[player][]slider_regular = map{}

        # Menu Nodes, each representing a page in the mainmenu
        var MainMenuNode:[player]ui_list_node = map{}
        var MapSpeedMenuNode:[player]ui_list_node = map{}
        var HealthMenuNode:[player]ui_list_node = map{}
        var SpectateMenuNode:[player]ui_list_node = map{}
        var RestartMenuNode:[player]ui_list_node = map{}
        var AllShieldsMenuNode:[player]ui_list_node = map{}
        var BalancedHealthMenuNode:[player]ui_list_node = map{}
        var CustomHealthMenuNode:[player]ui_list_node = map{}
        var SlowSpeedMenuNode:[player]ui_list_node = map{}
        var FastSpeedMenuNode:[player]ui_list_node = map{}

        # Background for the menu
        var Background:[player]canvas = map{}
        # A map of Nodes(Pages) with the ui buttons on the pages
        var MenuNodeMap:[ui_list_node][]button_regular = map{}
        # Number of players in the 1v1 zone
        var NumberOfPlayersInZone:int = 0
        # A map that assigns Map Menu to Player - Used for getting the map menu UI in order to remove it
        var MaybeMapMenuUI:[player]?ui_linked_list = map{}
        # Number of players in the map excluding spectators
        var AllPlayers<public>:[]player = array{}
        # Instance of a class that manages player health
        var HealthManager<public>:healthmanager = healthmanager{}
        # The current cinematic sequence device running
        var CurrentCinematic:cinematic_sequence_device = cinematic_sequence_device{}
        # The canvas for the 1v1 timer
        var TimerCanvas:canvas = canvas{}

        
        OnBegin<override>()<suspends>:void =
            InitializePlayers()
            InitializeSpawnPads()
            Sleep(0.0)
            InitializeMapMenu()
            MenuButton.InteractedWithEvent.Subscribe(OnMenuButtonPressed)
            GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerJoiningMap)

        # Called when player joins the game
        OnPlayerJoiningMap(Agent:agent):void =
            if(Player := player[Agent]):
                InitializeUIButtons(Player)
                AssignUI(Player) 

        # Hides HUD for Player. (Not working properly according to epic since it affects all players)
        HideHud(Player:player):void = {}
            # if(PlayerUI := GetPlayerUI[Player]):
            #     PlayerUI.HideHUDElements(HUDElements)
        
        # Shows HUD for Player. (Not working properly according to epic since it affects all players)
        ShowHud(Player:player):void =
            if(PlayerUI := GetPlayerUI[Player]):
                PlayerUI.ShowHUDElements(HUDElements)

        # Stops any previous Speed cinematic playing and plays assigned cinematic
        Play(Cinematic:cinematic_sequence_device):void =
            CurrentCinematic.Stop()
            set CurrentCinematic = Cinematic
            CurrentCinematic.Play()
            
        # Initialize Spawnpads
        InitializeSpawnPads():void =
            for(SpawnPad:SpawnPads):
                SpawnPad.SpawnedEvent.Subscribe(OnPlayerSpawned)

        # Changes player health when player spawns
        OnPlayerSpawned(Agent:agent):void =
            if:
                Player := player[Agent]
                FortCharacter := Player.GetFortCharacter[]
                # GetPlayers()[0] because player joining progress needs a value
                # Hence, they can use the value of player they meet in map
                ShieldSlider := CustomHealthSliders[GetPlayers()[0]][0]
                HealthSlider := CustomHealthSliders[GetPlayers()[0]][1]
            then:
                FortCharacter.SetMaxShield(ShieldSlider.GetValue())
                FortCharacter.SetMaxHealth(HealthSlider.GetValue())
            
        # Returns the UI of the Player's current Node
        GetMenuUI(Player:player)<transacts><decides>:canvas =
            var UI:canvas = canvas{}
            if:
                List := MaybeMapMenuUI[Player]?
                Node := List.CurrentNode
            then:
                set UI = Node.CurrentUI
            return UI
        
        # Assigns all players excluding spectators to an array
        InitializePlayers():void = 
            set AllPlayers =
                for:
                    Player:GetPlayspace().GetPlayers()
                    not Player.IsSpectator[]
                do:
                    Player
            HealthManager.ChangeHealth(AllPlayers)

        # Initializes all Menu Nodes and assigns ui buttons to them
        InitializeMapMenu():void =
            for(Player:GetPlayers()):
                OnPlayerJoiningMap(Player)

        # Assigns all canvas UI to Player Maps
        AssignUI(Player:player):void =
            Canvas := ColorBlockCanvas()
            option {set Background[Player] = Canvas}
            var UI:canvas = MainMenu(Player)
            option:
                set MainMenuNode[Player] =
                    ui_list_node:
                        CurrentUI := UI
            set UI = MapSpeedMenu(Player)
            option:
                set MapSpeedMenuNode[Player] =
                    ui_list_node:
                        Previous := option{MainMenuNode[Player]}
                        CurrentUI := UI
            set UI = HealthMenu(Player)
            option:
                set HealthMenuNode[Player] =
                    ui_list_node:
                        Previous := option{MainMenuNode[Player]}
                        CurrentUI := UI
            set UI = SpectateMenu(Player)
            option:
                set SpectateMenuNode[Player] =
                    ui_list_node:
                        CurrentUI := UI
            set UI = RestartMenu(Player)
            option:
                set RestartMenuNode[Player] =
                    ui_list_node:
                        CurrentUI := UI
            set UI = AllShieldsMenu(Player)
            option:
                set AllShieldsMenuNode[Player] =
                    ui_list_node:
                        CurrentUI := UI
            set UI = BalancedHealthMenu(Player)
            option:
                set BalancedHealthMenuNode[Player] =
                    ui_list_node:
                        CurrentUI := UI
            set UI = CustomHealthMenu(Player)
            option:
                set CustomHealthMenuNode[Player] =
                    ui_list_node:
                        CurrentUI := UI
            set UI = SlowSpeedMenu(Player)
            option:
                set SlowSpeedMenuNode[Player] =
                    ui_list_node:
                        CurrentUI := UI
            set UI = FastSpeedMenu(Player)
            option:
                set FastSpeedMenuNode[Player] =
                    ui_list_node:
                        CurrentUI := UI
                    
            option:
                Buttons := MainMenuButtons[Player]
                set MenuNodeMap[MainMenuNode[Player]] = Buttons
            option:
                Buttons := MapSpeedButtons[Player]
                set MenuNodeMap[MapSpeedMenuNode[Player]] = Buttons
            option:
                Buttons := HealthButtons[Player]
                set MenuNodeMap[HealthMenuNode[Player]] = Buttons
            option:
                Buttons := SpectateButtons[Player]
                set MenuNodeMap[SpectateMenuNode[Player]] = Buttons
            option:
                Buttons := RestartButtons[Player]
                set MenuNodeMap[RestartMenuNode[Player]] = Buttons
            option:
                Buttons := AllShieldsButtons[Player]
                set MenuNodeMap[AllShieldsMenuNode[Player]] = Buttons
            option:
                Buttons := BalancedHealthButtons[Player]
                set MenuNodeMap[BalancedHealthMenuNode[Player]] = Buttons
            option:
                Buttons := CustomHealthButtons[Player]
                set MenuNodeMap[CustomHealthMenuNode[Player]] = Buttons
            option:
                Buttons :=  SlowSpeedButtons[Player]
                set MenuNodeMap[SlowSpeedMenuNode[Player]] = Buttons
            option:
                Buttons := FastSpeedButtons[Player]
                set MenuNodeMap[FastSpeedMenuNode[Player]] = Buttons


        
        # Creates a color block canvas
        ColorBlockCanvas():canvas =
            canvas:
                Slots := array:
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.0, Y := 0.0}, Maximum := vector2{X := 1.0, Y := 1.0}}
                        #Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := texture_block:
                            DefaultImage := MainMenu_Background
                            DefaultDesiredSize := vector2{X := 1920.0, Y := 1080.0}
                        # Widget := color_block:
                        #     DefaultColor := MakeColorFromHex(MenuColor.Color)
                        #     DefaultOpacity := MenuColor.Opacity
                        #     DefaultDesiredSize := MenuColor.Size
                        

        # Returns the main menu canvas
        MainMenu(Player:player):canvas =
            canvas:
                Slots := array:
                    canvas_slot:
                        Anchors := Anchor
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := text_block:
                            DefaultText := ToMessage("MAIN MENU")
                            DefaultTextColor := White
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        # Arrange the UI Buttons in a stack box
                        Widget := stack_box:
                                Orientation := orientation.Vertical
                                Slots := 
                                    for(Button:MainMenuButtons[Player]):
                                        stack_box_slot:
                                            Padding := margin{Bottom := 10.0}
                                            Widget := Button
        # Returns the map speed menu canvas
        MapSpeedMenu(Player:player):canvas =
            canvas:
                Slots := array:
                    canvas_slot:
                        Anchors := Anchor
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := text_block:
                            DefaultText := ToMessage("MAP SPEED MENU")
                            DefaultTextColor := White
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        # Arrange the UI Buttons in a stack box
                        Widget := stack_box:
                            Orientation := orientation.Vertical
                            Slots := 
                                for(Button:MapSpeedButtons[Player]):
                                    stack_box_slot:
                                        Padding := margin{Bottom := 10.0}
                                        Widget := Button
        # Returns the health menu canvas                      
        HealthMenu(Player:player):canvas =
            canvas:
                Slots := array:
                    canvas_slot:
                        Anchors := Anchor
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := text_block:
                            DefaultText := ToMessage("HEALTH MENU")
                            DefaultTextColor := White
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.4, Y := 0.3}, Maximum := vector2{X := 0.4, Y := 0.3}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := stack_box:
                            Orientation := orientation.Vertical
                            Slots := array:
                                stack_box_slot:
                                    Widget := text_block:
                                        DefaultText := ToMessage("All Shields - 1 Health")
                                        DefaultTextColor := White
                                stack_box_slot:
                                    Widget := text_block:
                                        DefaultText := ToMessage("Balanced - 100 Health")
                                        DefaultTextColor := White
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        # Arrange the UI Buttons in a stack box
                        Widget := stack_box:
                            Orientation := orientation.Vertical
                            Slots := 
                                for(Button:HealthButtons[Player]):
                                    stack_box_slot:
                                        Padding := margin{Bottom := 10.0}
                                        Widget := Button

        # Returns the Spectate menu canvas
        SpectateMenu(Player:player):canvas =
            canvas:
                Slots := array:
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.3}, Maximum := vector2{X := 0.5, Y := 0.3}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := text_block:
                            DefaultText := ToMessage("SPECTATE MENU")
                            DefaultTextColor := White
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.4}, Maximum := vector2{X := 0.5, Y := 0.4}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := text_block:
                            DefaultText:=ToMessage("Switch to spectate?")
                            DefaultTextColor := Red
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        # Arrange the UI Buttons in a stack box
                        Widget := stack_box:
                            Orientation := orientation.Horizontal
                            Slots := 
                                for(Button:SpectateButtons[Player]):
                                    stack_box_slot:
                                        Padding := margin{Left := 50.0, Right := 50.0}
                                        Widget := Button
        
        # Returns the Restart menu canvas
        RestartMenu(Player:player):canvas =
            canvas:
                Slots := array:
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.3}, Maximum := vector2{X := 0.5, Y := 0.3}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := text_block:
                            DefaultText := ToMessage("RESTART MENU")
                            DefaultTextColor := White
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.4}, Maximum := vector2{X := 0.5, Y := 0.4}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := text_block:
                            DefaultText:=ToMessage("Restart Map?")
                            DefaultTextColor := Red
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        # Arrange the UI Buttons in a stack box
                        Widget := stack_box:
                            Orientation := orientation.Horizontal
                            Slots := 
                                for(Button:RestartButtons[Player]):
                                    stack_box_slot:
                                        Padding := margin{Left := 50.0, Right := 50.0}
                                        Widget := Button

        # Returns the AllShields menu canvas
        AllShieldsMenu(Player:player): canvas = 
            canvas:
                Slots := array:
                    canvas_slot:
                        Anchors := Anchor
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := text_block:
                            DefaultText := ToMessage("ALL SHIELDS MENU")
                            DefaultTextColor := White
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        # Arrange the UI Buttons in a stack box
                        Widget := stack_box:
                            Orientation := orientation.Vertical
                            Slots := 
                                for(Button:AllShieldsButtons[Player]):
                                    stack_box_slot:
                                        Padding := margin{Top := 10.0}
                                        Widget := Button
        
        # Returns the Balanced Health menu canvas
        BalancedHealthMenu(Player:player): canvas =
            canvas:
                Slots := array:
                    canvas_slot:
                        Anchors := Anchor
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := text_block:
                            DefaultText := ToMessage("BALANCED HEALTH MENU")
                            DefaultTextColor := White
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        # Arrange the UI Buttons in a stack box
                        Widget := stack_box:
                            Orientation := orientation.Vertical
                            Slots := 
                                for(Button:BalancedHealthButtons[Player]):
                                    stack_box_slot:
                                        Padding := margin{Top := 10.0}
                                        Widget := Button
        
        # Returns the Balanced Health menu canvas
        CustomHealthMenu(Player:player): canvas =
            CreateUISliders(Player)
            canvas:
                Slots := array:
                    canvas_slot:
                        Anchors := Anchor
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := text_block:
                            DefaultText := ToMessage("CUSTOM HEALTH MENU")
                            DefaultTextColor := White
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.4, Y := 0.54}, Maximum := vector2{X := 0.4, Y := 0.54}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := stack_box:
                            Orientation := orientation.Vertical
                            Slots := array:
                                stack_box_slot:
                                    Widget := text_block:
                                        DefaultText := ToMessage("Shields:")
                                        DefaultTextColor := Blue
                                stack_box_slot:
                                    Padding := margin{Top := 40.0}
                                    Widget := text_block:
                                        DefaultText := ToMessage("Health:")
                                        DefaultTextColor := LimeGreen
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := stack_box:
                            Orientation := orientation.Vertical
                            Slots :=
                                for(Slider:CustomHealthSliders[Player]):
                                    stack_box_slot:
                                        Padding := margin{Top := 50.0}
                                        Widget := Slider
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.7}, Maximum := vector2{X := 0.5, Y := 0.7}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        # Arrange the UI Buttons in a stack box
                        Widget := stack_box:
                            Orientation := orientation.Horizontal
                            Slots := 
                                for(Button:CustomHealthButtons[Player]):
                                    stack_box_slot:
                                        Padding := margin{Left := 25.0, Right := 25.0}
                                        Widget := Button
                                    
        
        # Returns the Slow Speed menu canvas
        SlowSpeedMenu(Player:player):canvas =
            canvas:
                Slots := array:
                    canvas_slot:
                        Anchors := Anchor
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := text_block:
                            DefaultText := ToMessage("SLOW SPEED MENU")
                            DefaultTextColor := White
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        # Arrange the UI Buttons in a stack box
                        Widget := stack_box:
                            Orientation := orientation.Vertical
                            Slots := 
                                for(Button:SlowSpeedButtons[Player]):
                                    stack_box_slot:
                                        Padding := margin{Top := 10.0}
                                        Widget := Button

        # Returns the Fast Speed menu canvas
        FastSpeedMenu(Player:player):canvas =
            canvas:
                Slots := array:
                    canvas_slot:
                        Anchors := Anchor
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := text_block:
                            DefaultText := ToMessage("FAST SPEED MENU")
                            DefaultTextColor := White
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        # Arrange the UI Buttons in a stack box
                        Widget := stack_box:
                            Orientation := orientation.Vertical
                            Slots := 
                                for(Button:FastSpeedButtons[Player]):
                                    stack_box_slot:
                                        Padding := margin{Top := 10.0}
                                        Widget := Button

        # Creates UI Sliders
        CreateUISliders(Player:player):void =
            option:
                FortCharacter := Player.GetFortCharacter[]
                set CustomHealthSliders[Player] = array:
                    slider_regular:
                        DefaultValue := FortCharacter.GetMaxShield()
                        # if minvalue is 0.0, player's can't get shield back with setmaxshield or setshield for some reason even
                        DefaultMinValue := 1.0
                        DefaultMaxValue := 200.0
                        DefaultStepSize := 0.5
                    slider_regular:
                        DefaultValue := FortCharacter.GetMaxHealth()
                        DefaultMinValue := 1.0
                        DefaultMaxValue := 200.0
                        DefaultStepSize := 0.5

        # Initializes all UI buttons
        InitializeUIButtons(Player:player):void =
            Buttons := array:
                Buttons1 := 
                    for(Text:MenuButtonNames):
                        Button := button_regular{DefaultText:=ToMessage(Text)}
                Buttons2 := 
                    for(MapSpeed:MapSpeeds):
                        Text := MapSpeed.SpeedType
                        Button := button_regular{DefaultText:=ToMessage(Text)}
                Buttons3 := array:
                    button_regular{DefaultText:=ToMessage("All Shields")}
                    button_regular{DefaultText:=ToMessage("Balanced")}
                    button_regular{DefaultText:=ToMessage("Custom")}
                    button_regular{DefaultText:=ToMessage("Back")}
                Buttons4 := array:
                    button_regular{DefaultText:=ToMessage("185")}
                    button_regular{DefaultText:=ToMessage("200")}
                    button_regular{DefaultText:=ToMessage("Back")}
                Buttons5 := array:
                    button_regular{DefaultText:=ToMessage("185")}
                    button_regular{DefaultText:=ToMessage("200")}
                    button_regular{DefaultText:=ToMessage("Back")}
                Buttons6 := array:
                    button_regular{DefaultText:=ToMessage("Okay")}
                    button_regular{DefaultText:=ToMessage("Back")}
                Buttons7 := array:
                    button_regular{DefaultText:=ToMessage("Yes")}
                        button_regular{DefaultText:=ToMessage("No")}
                Buttons8 := array:
                    button_regular{DefaultText:=ToMessage("Yes")}
                        button_regular{DefaultText:=ToMessage("No")}
                Buttons9 :=
                    for(Text:MapSpeeds[0].Speeds):
                        Button := button_regular{DefaultText:=ToMessage(Text)}
                Buttons10 :=
                    for(Text:MapSpeeds[2].Speeds):
                        Button := button_regular{DefaultText:=ToMessage(Text)}

            option {set MainMenuButtons[Player] = Buttons1}
            option {set MapSpeedButtons[Player] = Buttons2}
            option {set HealthButtons[Player] = Buttons3}
            option {set AllShieldsButtons[Player] = Buttons4}
            option {set BalancedHealthButtons[Player] = Buttons5}
            option {set CustomHealthButtons[Player] = Buttons6}
            option {set RestartButtons[Player] = Buttons7}
            option {set SpectateButtons[Player] = Buttons8}
            option {set SlowSpeedButtons[Player] = Buttons9}
            option {set FastSpeedButtons[Player] = Buttons10}

            SubscribeUIButtons(Buttons)
        
        # Subscribes UI Buttons
        SubscribeUIButtons(ButtonGroup:[][]button_regular):void =
            for(Buttons:ButtonGroup, Button:Buttons):
                Button.OnClick().Subscribe(OnClickingButton)     

        # Gets the Button, Player and Menu UI, then proceeds to the function of the ui button
        OnClickingButton(Message:widget_message):void =
            if:
                Player := Message.Player
                ClickedButton := text_button_base[Message.Source]
                MenuUI := GetMenuUI[Player]
            then:
                Print("UI button clicked")
                HandleUIButtonClick(ClickedButton, Player, MenuUI)
        
        # Handles the actions of each UI Button
        HandleUIButtonClick(ClickedButton:text_button_base, Player:player, MenuUI:canvas):void =
            if(PlayerUI := GetPlayerUI[Player]):
                # Remove current Widget before showing another one
                PlayerUI.RemoveWidget(MenuUI)

                # Check if UI button is from main menu
                if(ClickedButton = MainMenuButtons[Player][0], Node := MapSpeedMenuNode[Player]):
                    Print("Clicked on Map Menu")
                    OpenMenu(Player, Node)
                else if(ClickedButton = MainMenuButtons[Player][1], Node := HealthMenuNode[Player]):
                    Print("Clicked on Health")
                    OpenMenu(Player, Node)
                else if(ClickedButton = MainMenuButtons[Player][2], Node := SpectateMenuNode[Player]):
                    Print("Clicked on Spectate")
                    OpenMenu(Player, Node)
                else if(ClickedButton = MainMenuButtons[Player][3], Node := RestartMenuNode[Player]):
                    Print("Clicked on Restart")
                    OpenMenu(Player, Node)
                else if(ClickedButton = MainMenuButtons[Player][MainMenuButtons[Player].Length - 1]):
                    Print("Clicked on Cancel")
                    RemoveMapMenuUI(Player)

                # Check if UI button is from Map Speed menu
                else if(ClickedButton = MapSpeedButtons[Player][0], Node := SlowSpeedMenuNode[Player]):
                    Print("Clicked on Slow Speed")
                    OpenMenu(Player, Node)
                else if(ClickedButton = MapSpeedButtons[Player][1]):
                    Print("Clicked on Normal Speed")
                    Play(NormalCinematics)
                    NormalSpeedMessage.Activate(Player)
                    RemoveMapMenuUI(Player)
                else if(ClickedButton = MapSpeedButtons[Player][2], Node := FastSpeedMenuNode[Player]):
                    Print("Clicked on Fast Speed")
                    OpenMenu(Player, Node)
                else if:
                        ClickedButton = MapSpeedButtons[Player][MapSpeedButtons[Player].Length - 1]
                        MaybeMapMenuUI[Player]?.Recede()
                then:
                    Print("Clicked on Back")
                    OpenUI(Player)

                # Check if UI button is from Health menu
                else if(ClickedButton = HealthButtons[Player][0], Node := AllShieldsMenuNode[Player]):
                    Print("Clicked on AllShields")
                    OpenMenu(Player, Node)
                else if(ClickedButton = HealthButtons[Player][1], Node := BalancedHealthMenuNode[Player]):
                    Print("Clicked on Balanced Health")
                    OpenMenu(Player, Node)
                else if(ClickedButton = HealthButtons[Player][2]):
                    Print("Clicked on Custom")
                    # Custom Health Page has to be recreated on every click 
                    # to modify the slider default valueto current max health and shield
                    UI := CustomHealthMenu(Player)
                    if:
                        set CustomHealthMenuNode[Player] =
                            ui_list_node:
                                CurrentUI := UI
                        Node := CustomHealthMenuNode[Player]
                    then {OpenMenu(Player, Node)}
                else if:
                    ClickedButton = HealthButtons[Player][HealthButtons[Player].Length - 1]
                    MaybeMapMenuUI[Player]?.Recede()
                then:
                    Print("Clicked on Back")
                    OpenUI(Player)

                # Check if UI button is from Spectate menu
                else if(ClickedButton = SpectateButtons[Player][0]):
                    Print("Clicked on Yes")
                    SpectatorManager.ChangeClass(Player)
                    if(FortCharacter := Player.GetFortCharacter[]):
                        RemoveMapMenuUI(Player)
                        FortCharacter.Damage(Inf)
                else if(ClickedButton = SpectateButtons[Player][1]):
                    Print("Clicked on No")
                    RemoveMapMenuUI(Player)

                # Check if UI button is from Restart menu
                else if(ClickedButton = RestartButtons[Player][0]):
                    Print("Clicked on Yes")
                    RemoveMapMenuUI(Player)
                    Endgame.Activate(Player)
                else if(ClickedButton = RestartButtons[Player][1]):
                    Print("Clicked on No")
                    RemoveMapMenuUI(Player)

                else:
                    var Index:int = 0
                    # Check if UI button is from AllShields menu
                    for(Button:AllShieldsButtons[Player]):
                        if(Button = ClickedButton):
                            Print("Clicked a button on AllShield")
                            if:
                                Button = AllShieldsButtons[Player][AllShieldsButtons[Player].Length - 1]
                                MaybeMapMenuUI[Player]?.Recede()
                            then:
                                Print("Clicked on Back")
                                OpenUI(Player)
                            else:
                                if(Health := MaxHealths[Index]):
                                    HealthManager.SetHealth(Health)
                                    HealthManager.SetHealthType(AllShields)
                                    HealthManager.ChangeHealth(AllPlayers)
                                    CreateUISliders(Player)
                                    RemoveMapMenuUI(Player)
                            return
                        set Index += 1

                    # Check if UI button is from Balanced Health menu
                    set Index = 0
                    for(Button:BalancedHealthButtons[Player]):
                        if(Button = ClickedButton):
                            Print("Clicked a button on Balanced")
                            if:
                                Button = BalancedHealthButtons[Player][BalancedHealthButtons[Player].Length - 1]
                                MaybeMapMenuUI[Player]?.Recede()
                            then:
                                Print("Clicked on Back")
                                OpenUI(Player)
                            else:
                                if(Health := MaxHealths[Index]):
                                    HealthManager.SetHealth(Health)
                                    HealthManager.SetHealthType(BalancedHealth)
                                    HealthManager.ChangeHealth(AllPlayers)
                                    CreateUISliders(Player)
                                    RemoveMapMenuUI(Player)
                            return
                        set Index += 1

                    # Check if UI button is from Custom Health menu
                    set Index = 0
                    for(Button:CustomHealthButtons[Player]):
                        if(Button = ClickedButton):
                            Print("Clicked a button on Custom")
                            if:
                                Button = CustomHealthButtons[Player][CustomHealthButtons[Player].Length - 1]
                                MaybeMapMenuUI[Player]?.Recede()
                            then:
                                Print("Clicked on Back")
                                OpenUI(Player)
                            else:
                                Print("Clicked on Okay")
                                # Set the healths and shields of all players to the values on the sliders
                                for:
                                    InPlayer:AllPlayers
                                    FortCharacter := InPlayer.GetFortCharacter[]
                                    ShieldSlider := CustomHealthSliders[Player][0]
                                    HealthSlider := CustomHealthSliders[Player][1]
                                do:
                                    FortCharacter.SetMaxShield(ShieldSlider.GetValue())
                                    FortCharacter.SetMaxHealth(HealthSlider.GetValue())
                                    RemoveMapMenuUI(Player)
                            return
                        set Index += 1

                    # Check if UI button is from Slow Speed menu
                    set Index = 0
                    for(Button:SlowSpeedButtons[Player]):
                        if(Button = ClickedButton):
                            if:
                                Button = SlowSpeedButtons[Player][SlowSpeedButtons[Player].Length - 1]
                                MaybeMapMenuUI[Player]?.Recede()
                            then:
                                Print("Clicked on Back")
                                OpenUI(Player)
                            else:
                                if:
                                    Cinematic := SlowCinematics[Index]
                                    SpeedMessage := SlowSpeedMessage[Index]
                                then:
                                    SpeedMessage.Activate(Player)
                                    Play(Cinematic)
                                    RemoveMapMenuUI(Player)
                            return
                        set Index += 1

                    # Check if UI button is from Fast Speed menu
                    set Index = 0
                    for(Button:FastSpeedButtons[Player]):
                        if(Button = ClickedButton):
                            if:
                                Button = FastSpeedButtons[Player][FastSpeedButtons[Player].Length - 1]
                                MaybeMapMenuUI[Player]?.Recede()
                            then:
                                Print("Clicked on Back")
                                OpenUI(Player)
                            else:
                                if:
                                    Cinematic := FastCinematics[Index]
                                    SpeedMessage := FastSpeedMessage[Index]
                                then:
                                    SpeedMessage.Activate(Player)
                                    Play(Cinematic)
                                    RemoveMapMenuUI(Player)
                            return
                        set Index += 1

        # Removes the Menu List assigned to player.
        # Means Player shouldn't have a UI anymore and can move freely
        RemoveMapMenuUI(Player:player):void =
            if:
                PlayerUI := GetPlayerUI[Player]
                set MaybeMapMenuUI[Player] = false
                UIBackground := Background[Player]
            then:
                PlayerUI.RemoveWidget(UIBackground)
                ShowHud(Player)
                Print("Removed Menu from Player Map{}")
            
        # Moves Adds a node to the UI Linked list before showing the node(page)
        OpenMenu(Player:player, Node:ui_list_node):void =
            if:
                List := MaybeMapMenuUI[Player]?
                List.Advance(Node)
                set MaybeMapMenuUI[Player] = option{List}
            Print("Showing Menu")
            OpenUI(Player)

        # Shows the UI on the Current Node
        OpenUI(Player:player):void =
            if:
                PlayerUI := GetPlayerUI[Player]
                UI := GetMenuUI[Player]
            then:
                PlayerUI.AddWidget(UI, player_ui_slot{InputMode:=ui_input_mode.All})
        
        # Shows a max height message
        DisplayMaxHeightMessage<public>(Player:player)<suspends>:void = 
            Canvas := canvas:
                Slots := array:
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.2}, Maximum := vector2{X := 0.5, Y := 0.2}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := text_block:
                            DefaultText := ToMessage("MAX HEIGHT!")
                            DefaultTextColor := Red
            if(PlayerUI := GetPlayerUI[Player]):
                PlayerUI.AddWidget(Canvas)
                Print("Added Max Height Widget")
                Sleep(3.0)
                PlayerUI.RemoveWidget(Canvas)
                Print("Removed Max Height Widget") 

        # Initializes the menu button
        OnMenuButtonPressed(Agent:agent):void =
            if:
                Player := player[Agent]
                PlayerUI := GetPlayerUI[Player]
                MapMenuList := CreateUIList(MainMenuNode[Player])
                set MaybeMapMenuUI[Player] = option{MapMenuList}
                UIBackground := Background[Player]
            then:
                Print("Added Menu List to Player Map")
                # For some reason, canvas and widgets are removed from player when another player triggers the function. 
                # Basically transfers the widgets to the new triggering player
                PlayerUI.AddWidget(UIBackground)
                HideHud(Player)
                OpenUI(Player)
                
        # Show player name as a message
        PlayerName<localizes>(Agent:agent):message = "{Agent}"
        # Convert string to message
        ToMessage<localizes><public>(Text:string):message = "{Text}"
        # Convert Agent and string to message in this format
        ToMessage<localizes>(Agent:agent, Text:string):message = "{Agent} {Text}"

        GetPlayers()<transacts>:[]player =
            Game_UI_Manager{}.GetPlayspace().GetPlayers()

// Settings > Game > Dialog Options Offset. The Options menu edits and saves the
// default object, so the extension below reads the current value from there.
UCLASS(Config=GameUserSettings)
class UDialogOptionsOffsetSettings : UGothicModExt_UserSettings
{
    default CategoryName = FText::FromString("Dialog Options Offset");

    UPROPERTY(Config)
    FModUserSettingsInt OffsetPercent = FModUserSettingsInt(
        Value = 13,
        DefaultValue = 13,
        DisplayText = FText::FromString("Move dialog right (% of screen width)"),
        MinValue = 0,
        MaxValue = 50);
}

class UDialogOptionsOffsetExtension : UGothicModExt_WidgetExtension
{
    default AddToWidgetOfClass = n"/Game/UI/Conversation/V2/W_ConversationMain.W_ConversationMain_C";

    UPROPERTY()
    TArray<URichTextBlock> SpeechLines;

    bool bCaptured = false;

    UFUNCTION(BlueprintOverride)
    bool RequiresTick() const
    {
        return true;
    }

    // Runs every frame because other UI mods can restore these transforms.
    UFUNCTION(BlueprintOverride)
    void Tick(FGeometry MyGeometry, float32 InDeltaTime)
    {
        auto Conversation = Cast<UConversationWidget>(GetWidget());
        if (!IsValid(Conversation))
            return;

        UWidget TopicList = Conversation.TopicListContainer;
        UWidget SubTopicList = Conversation.SubTopicListContainer;
        if (!IsValid(TopicList) || !IsValid(SubTopicList))
            return;

        if (!bCaptured)
        {
            bCaptured = true;
            CaptureSpeechLines(Conversation);
        }

        float32 Offset = float32(MyGeometry.GetLocalSize().X * UDialogOptionsOffsetSettings.DefaultObject.OffsetPercent.Value * 0.01);

        // Move everything in the box that holds both lists, so whatever sits
        // above them stays aligned. The children are moved rather than the box
        // itself because other UI mods reset the box's position every frame.
        UPanelWidget Box = TopicList.GetParent();
        if (IsValid(Box) && Box == SubTopicList.GetParent() && Box != Conversation.GetRootWidget())
        {
            for (auto Child : Box.GetAllChildren())
                MoveTo(Child, Offset);
        }
        else
        {
            MoveTo(TopicList, Offset);
            MoveTo(SubTopicList, Offset);
        }

        // Only left-aligned speech starts too far left. Centered speech stays put.
        for (auto Line : SpeechLines)
        {
            if (IsValid(Line) && Line.Justification == ETextJustify::Left)
                MoveSpeechLine(Line, Offset);
        }
    }

    void CaptureSpeechLines(UConversationWidget Conversation)
    {
        TArray<UWidget> Widgets;
        Conversation.GetAllWidgetsAndDescendants(Widgets);

        // TEMPORARY: the widget layout can't be read outside the game, so write
        // it to a file while the speech offset is being tested.
        FString Tree;
        for (auto Item : Widgets)
        {
            auto Line = Cast<URichTextBlock>(Item);
            if (IsValid(Line) && Item.Name.ToString().Contains("DialogueLine"))
                SpeechLines.Add(Line);

            Tree += Item.Name.ToString() + " | " + Item.Class.Name.ToString()
                + " | slot: " + (IsValid(Item.Slot) ? Item.Slot.Class.Name.ToString() : "-")
                + " | parent: " + (IsValid(Item.GetParent()) ? Item.GetParent().Name.ToString() : "-") + "\n";
        }
        FFileHelper::SaveStringToFile(Tree, System::GetProjectSavedDirectory() + "DialogOptionsOffset-widgets.txt");
    }

    void MoveTo(UWidget Item, float Offset)
    {
        FVector2D Current = Item.RenderTransform.Translation;
        if (Current.X != Offset)
            Item.SetRenderTranslation(FVector2D(Offset, Current.Y));
    }

    // Prefer left padding: the line then wraps inside the remaining width, so
    // long lines stay on screen. A render offset would push them past the edge.
    void MoveSpeechLine(URichTextBlock Line, float32 Offset)
    {
        auto VerticalBox = Cast<UVerticalBoxSlot>(Line.Slot);
        auto Overlay = Cast<UOverlaySlot>(Line.Slot);
        auto Border = Cast<UBorderSlot>(Line.Slot);
        auto SizeBox = Cast<USizeBoxSlot>(Line.Slot);

        if (IsValid(VerticalBox))
            VerticalBox.SetPadding(WithLeft(VerticalBox.GetPadding(), Offset));
        else if (IsValid(Overlay))
            Overlay.SetPadding(WithLeft(Overlay.GetPadding(), Offset));
        else if (IsValid(Border))
            Border.SetPadding(WithLeft(Border.GetPadding(), Offset));
        else if (IsValid(SizeBox))
            SizeBox.SetPadding(WithLeft(SizeBox.GetPadding(), Offset));
        else
            MoveTo(Line, Offset);
    }

    FMargin WithLeft(FMargin Padding, float32 Left)
    {
        FMargin Result = Padding;
        Result.Left = Left;
        return Result;
    }
}

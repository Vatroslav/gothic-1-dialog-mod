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
        if (!IsValid(Conversation) || !IsValid(Conversation.TopicListContainer))
            return;

        if (!bCaptured)
        {
            bCaptured = true;
            CaptureSpeechLines(Conversation);
        }

        float32 Offset = float32(MyGeometry.GetLocalSize().X * UDialogOptionsOffsetSettings.DefaultObject.OffsetPercent.Value * 0.01);

        // Both lists and the tooltip above them share one vertical box. Its
        // children are moved rather than the box itself because other UI mods
        // reset the box's position every frame.
        for (auto Child : Conversation.TopicListContainer.GetParent().GetAllChildren())
        {
            FVector2D Current = Child.RenderTransform.Translation;
            if (Current.X != Offset)
                Child.SetRenderTranslation(FVector2D(Offset, Current.Y));
        }

        // Only left-aligned speech starts too far left. Centered speech stays put.
        // Left padding makes the line wrap inside the remaining width, so long
        // lines stay on screen. A render offset would push them past the edge.
        for (auto Line : SpeechLines)
        {
            auto Slot = Cast<UBorderSlot>(Line.Slot);
            if (IsValid(Slot) && Line.Justification == ETextJustify::Left)
            {
                FMargin Padding = Slot.GetPadding();
                Padding.Left = Offset;
                Slot.SetPadding(Padding);
            }
        }
    }

    void CaptureSpeechLines(UConversationWidget Conversation)
    {
        TArray<UWidget> Widgets;
        Conversation.GetAllWidgetsAndDescendants(Widgets);
        for (auto Item : Widgets)
        {
            auto Line = Cast<URichTextBlock>(Item);
            if (IsValid(Line) && Item.Name.ToString().Contains("DialogueLine"))
                SpeechLines.Add(Line);
        }
    }
}

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
        DisplayText = FText::FromString("Move options right (% of screen width)"),
        MinValue = 0,
        MaxValue = 50);
}

class UDialogOptionsOffsetExtension : UGothicModExt_WidgetExtension
{
    default AddToWidgetOfClass = n"/Game/UI/Conversation/V2/W_ConversationMain.W_ConversationMain_C";

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

        float Offset = MyGeometry.GetLocalSize().X * UDialogOptionsOffsetSettings.DefaultObject.OffsetPercent.Value * 0.01;

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
    }

    void MoveTo(UWidget Item, float Offset)
    {
        FVector2D Current = Item.RenderTransform.Translation;
        if (Current.X != Offset)
            Item.SetRenderTranslation(FVector2D(Offset, Current.Y));
    }
}

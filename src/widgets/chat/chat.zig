/// Chat widgets, the message kinds of the zigame editor's chat pane.
///
/// Each widget follows the design-system contract (value-type builder, copy-on-set
/// setters, terminal `draw()`, styling from `tokens.current`). Consumers use them as
/// `ds.chat.message(...)`, `ds.chat.toolCard(...)`, etc. The per-file doc comment
/// carries the visual/behaviour contract the implementation must meet; the
/// storybook pages `chat` and `chat_cards` showcase every state, and
/// `test/chat_screenshots.zig` / `test/card_screenshots.zig` are the fixtures.
pub const message = @import("message.zig").message;
pub const Message = @import("message.zig").Message;
pub const Role = @import("message.zig").Role;

pub const markdown = @import("markdown.zig").markdown;
pub const Markdown = @import("markdown.zig").Markdown;

pub const codeBlock = @import("code_block.zig").codeBlock;
pub const CodeBlock = @import("code_block.zig").CodeBlock;

pub const composer = @import("composer.zig").composer;
pub const composerMetrics = @import("composer.zig").composerMetrics;
pub const composerFont = @import("composer.zig").composerFont;
pub const ComposerMetrics = @import("composer.zig").Metrics;
pub const Composer = @import("composer.zig").Composer;
pub const ComposerResult = @import("composer.zig").ComposerResult;

pub const toolCard = @import("tool_card.zig").toolCard;
pub const ToolCard = @import("tool_card.zig").ToolCard;
pub const ToolStatus = @import("tool_card.zig").ToolStatus;

pub const approvalCard = @import("approval_card.zig").approvalCard;
pub const ApprovalCard = @import("approval_card.zig").ApprovalCard;
pub const ApprovalChoice = @import("approval_card.zig").ApprovalChoice;

pub const questionCard = @import("question_card.zig").questionCard;
pub const QuestionCard = @import("question_card.zig").QuestionCard;
pub const Question = @import("question_card.zig").Question;
pub const QuestionOption = @import("question_card.zig").Option;
pub const Selection = @import("question_card.zig").Selection;

pub const screenshotCard = @import("screenshot_card.zig").screenshotCard;
pub const ScreenshotCard = @import("screenshot_card.zig").ScreenshotCard;

pub const planCard = @import("plan_card.zig").planCard;
pub const PlanCard = @import("plan_card.zig").PlanCard;
pub const PlanChoice = @import("plan_card.zig").PlanChoice;

pub const errorCard = @import("error_card.zig").errorCard;
pub const ErrorCard = @import("error_card.zig").ErrorCard;

pub const checkpoint = @import("checkpoint.zig").checkpoint;
pub const Checkpoint = @import("checkpoint.zig").Checkpoint;

test {
    _ = @import("message_tests.zig");
    _ = @import("markdown_tests.zig");
    _ = @import("code_block_tests.zig");
    _ = @import("composer_tests.zig");
    _ = @import("tool_card_tests.zig");
    _ = @import("approval_card_tests.zig");
    _ = @import("question_card_tests.zig");
    _ = @import("screenshot_card_tests.zig");
    _ = @import("plan_card_tests.zig");
    _ = @import("error_card_tests.zig");
    _ = @import("checkpoint_tests.zig");
}

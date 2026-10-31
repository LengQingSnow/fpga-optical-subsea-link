# BER 统计输入约定

输入 JSON 顶层含 `lanes`（例如 `["TX0","TX2"]`）和 `windows`。每窗字段：

- `id`：唯一窗口标识；`time`：带时区 ISO 8601 采集时间。
- `valid`：布尔值；`errors` / `bits`：有效窗的非负错误整数 / 正的比较比特整数，无效窗两者均为 null。
- `capture_id`、`reference_id`：可追溯且非空的来源标识，建议 SHA256。
- `train_ranges`、`test_ranges`：在该捕获同一索引空间内、按位计的 `[start,end)` 区间列表。有效窗测试区间总长必须等于 bits，不可与训练区间重叠，也不可重复计入同一捕获的测试区间。这是统计导出格式，不是现有 MATLAB 结构体的隐式兼容声明。
- `ber`：可选；有效窗必须等于 errors/bits，无效窗只能为 null。

`bits` 包含哪些通道由顶层 lanes 决定；若按多通道展开，区间也必须使用展开后的统一比特索引。无监督算法可以给空的 train_ranges，但仍应记录使用的同步/调参区间，不能把训练位伪装成无监督。

输出只有加权统计及缺失窗计数，不填补任何无效值。示例和反例在 --self-test 中；它们都是合成数字。

完整的最小合成输入见 [example_audit.json](../assets/example_audit.json)，可直接用于首次运行。

# PocketBase 基础迁移

此目录保留四个基础迁移：study_workspaces、campus_content、course_notes、user_courses。全新数据库安装仍依赖这些文件，后续生产迁移位于 deploy/pocketbase/pb_migrations。

当前业务后端已采用 PocketBase，本目录名称保留历史路径，便于安装脚本继续引用。账号与实际业务结构见[数据模型](../../docs/DATA_MODEL.md)。

本机试验使用独立数据目录与普通测试账号；生产升级按[部署手册](../../docs/REMOTE_DEPLOYMENT.md)执行。测试文件、pb_data 和可执行程序存放在 Git 忽略位置。

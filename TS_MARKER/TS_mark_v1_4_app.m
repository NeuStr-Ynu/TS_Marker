  function TS_mark_v1_4_app(app,start_index,image_folder,output_folder)
% TS_mark_v1_4_app(start_index,image_folder,output_folder)
% 本程序为TS mark app的核心函数 vision 1.4
% 程序开始时会弹窗选择图片文件夹和输出文件夹位置，请注意正确选择
% 键位说明:
%       Shift:         标记初始点
%       空格键:        开始标记点
%       鼠标右键:      标记一个点
%       delete:        撤销上一个点
%       Enter:         下一张图
% 需要输出文件名称使用下函数
%   save_fig(fig, res_dir, mission_code, i, fig_code, Tint)
% 2025/09/26    取消了输入时间间隔
% 2025/09/27    加入了GUI界面
%% 选择文件夹
% 选择输入文件夹
% image_folder = uigetdir('', '选择输入图片文件夹');
if image_folder == 0
    disp('未选择输入文件夹，程序退出');
    return;
end

% 选择输出文件夹
% output_folder = uigetdir('', '选择输出文件夹');
if output_folder == 0
    disp('未选择输出文件夹，程序退出');
    return;
end

%% 主程序
global start_point
global end_point
global se_flag
se_flag=0;

image_files_temp = dir(fullfile(image_folder, '*.png'));
num_images = length(image_files_temp);

% 提取图片编号并排序，并提取时间信息
for i = 1:num_images
    fig_str = split(image_files_temp(i).name, {'_','-','.'});
    image_files_temp(i).num = str2num(fig_str{2});
    
    image_files_temp(i).start_time = datetime([fig_str{6},'-',fig_str{7},'-',fig_str{8},'_',fig_str{9}], 'InputFormat', 'yyyy-MM-dd_HHmm');
    image_files_temp(i).end_time = datetime([fig_str{10},'-',fig_str{11},'-',fig_str{12},'_',fig_str{13}], 'InputFormat', 'yyyy-MM-dd_HHmm');
    image_files_temp(i).time_interval = minutes(image_files_temp(i).end_time - image_files_temp(i).start_time);
end

[~, idx] = sort([image_files_temp.num]);
image_files = image_files_temp(idx);

if start_index > num_images
    error('起始索引超出文件夹中的图片数量！');
end

% 创建输出文件夹（如果不存在）
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

start_fig_index = find([image_files.num] == start_index);

% 打开文件以追加数据
time_file_path = fullfile(output_folder, 'time_info.txt');
time_file = fopen(time_file_path, 'a');
if time_file == -1
    error('无法打开 time_info.txt，请检查输出文件夹是否可写。');
end

for i = start_fig_index:num_images

    img_path = fullfile(image_folder, image_files(i).name);
    img = imread(img_path);
    
    % 创建全屏窗口
    fig = figure('Units', 'normalized', 'OuterPosition', [0 0 1 1], 'WindowState', 'maximized');
    imshow(img);
    hold on;
    title(['当前图片: ', image_files(i).name], 'Interpreter', 'none');

    % 初始化存储
    setappdata(fig, 'points', []); 
    setappdata(fig, 'rectangles', []); 
    setappdata(fig, 'markedPoints', []); 
    setappdata(fig, 'finished', false);
    setappdata(fig, 'time_file', time_file);  % 存储time_file

    % 绑定键盘回调
    set(fig, 'KeyPressFcn', @(src, event) keyPressCallback(src, event, img, image_files(i).start_time, image_files(i).time_interval));

    while ~getappdata(fig, 'finished')
        uiwait(fig);  % 等待键盘输入
    end

    % 保存标记后的图片
    if ~isempty(getappdata(fig, 'rectangles'))
        output_path = fullfile(output_folder, image_files(i).name);
        saveas(fig, output_path);
    end
    close(fig);

    drawnow;
    if isprop(app, 'stopFlag') && app.stopFlag
        % 弹出提示窗口
        uialert(app.UIFigure, '已点击停止按钮，标记结束！', '提示');
        close all
        break;  % 退出循环
    end
end

% 关闭文件
fclose(time_file);

disp('程序结束');
end

%% -------------------------------
%  键盘事件回调函数
%  -------------------------------
function keyPressCallback(src, event, img, start_time, interval)
    global start_point
    global end_point
    global se_flag

    % 读取存储的标记信息
    points = getappdata(src, 'points');
    rectangles = getappdata(src, 'rectangles');
    markedPoints = getappdata(src, 'markedPoints');  % 记录每个点的绘制对象
    time_file = getappdata(src, 'time_file');  % 获取time_file

    switch event.Key

        case 'shift'
            se_flag = se_flag + 1;
            if se_flag == 1
                [x, y] = ginput(1);
                start_point = [x, y];
                disp(['起始点已设置：', num2str(start_point(1)), ', ', num2str(start_point(2))]); % Debug
                plot(x, y, 'go', 'MarkerSize', 3, 'LineWidth', 0.5);
            elseif se_flag == 2
                [x, y] = ginput(1);
                end_point = [x, y];
                disp(['终止点已设置：', num2str(end_point(1)), ', ', num2str(end_point(2))]); % Debug
                plot(x, y, 'go', 'MarkerSize', 3, 'LineWidth', 0.5);
            else
                disp('你已经选择过起始点和终止点了');
            end

        case 'space'  % 按下空格键，标记点
            [x, y] = ginput(1);
            points = [points; x, y];  % 记录新标记点
            p = plot(x, y, 'go', 'MarkerSize', 4, 'LineWidth', 1);
            markedPoints{end+1} = p;  % 存储标记点

            if mod(size(points, 1), 2) == 0  % 每两个点形成一个矩形
                x_min = min(points(end-1:end, 1));
                width = abs(points(end, 1) - points(end-1, 1));
                height = size(img, 1);
                rect = rectangle('Position', [x_min, 1, width, height], 'EdgeColor', 'r', 'LineWidth', 1.5);
                rectangles{end+1} = rect;
            end

        case 'delete'  % 撤销上一步操作（仅撤回最后一个点及其矩形）
            if ~isempty(points)
                % 删除最后一个点
                delete(markedPoints{end});
                markedPoints(end) = [];
                points(end, :) = [];

                % 如果撤销的点属于一个矩形，删除最后一个矩形
                if mod(size(points, 1), 2) == 1 && ~isempty(rectangles)
                    delete(rectangles{end});  % 删除最后一个矩形
                    rectangles(end) = [];
                end    
            end

        case 'return'  % 按回车键完成标记
            % 确保 start_point 和 end_point 已经被定义
            if isempty(start_point) || isempty(end_point)
                disp('请先按 Shift 选择起始点和终止点！');
                return;
            end

            % 计算时间信息并保存
            x_start = start_point(1);
            x_end = end_point(1);
            disp(x_start)
            disp(x_end)
            disp(points)
            
            % 图像宽度
            img_width = size(img, 2);
            time_diff = interval / (x_end - x_start);
            disp(img_width)
            if mod(size(points, 1), 2) ~= 0
                disp('在图上标记的点必须是偶数个！');
                ret urn;
            end


            for i = 1:size(points, 1)/2
                % 计算时间间隔（以分钟为单位）
                start_time_in = (points(2*i-1,1) - x_start);
                end_time_in = (points(2*i,1) - x_start);
                start_time_str = start_time + minutes(start_time_in * time_diff);
                end_time_str = start_time + minutes(end_time_in * time_diff);
    
                % 格式化时间输出
                start_time_formatted = datestr(start_time_str, 'yyyy.mm.dd.HH.MM.SS.FFF');
                end_time_formatted = datestr(end_time_str, 'yyyy.mm.dd.HH.MM.SS.FFF');
    
                % 写入时间到文件
                fprintf(time_file, '%s:%s,\n', start_time_formatted, end_time_formatted);
            end
            
            setappdata(src, 'finished', true);
            uiresume(src);  % 继续执行主程序

        case 'escape'  % 按 ESC 退出当前图片
            setappdata(src, 'finished', true);
            uiresume(src);  % 继续执行主程序
    end

    % 存储修改后的标记信息
    setappdata(src, 'points', points);
    setappdata(src, 'rectangles', rectangles);
    setappdata(src, 'markedPoints', markedPoints);
end

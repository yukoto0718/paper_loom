// API基础URL
const API_BASE = '/api/v1';

// 全局变量
let currentJobId = null;
let currentFileName = null;

// DOM元素
const uploadBox = document.getElementById('uploadBox');
const fileInput = document.getElementById('fileInput');
const processBtn = document.getElementById('processBtn');
const ocrModel = document.getElementById('ocrModel');
const statusSection = document.getElementById('statusSection');
const statusText = document.getElementById('statusText');
const resultSection = document.getElementById('resultSection');
const downloadBtn = document.getElementById('downloadBtn');
const markdownPreview = document.getElementById('markdownPreview');
const stats = document.getElementById('stats');

// 上传框点击事件
uploadBox.addEventListener('click', () => {
    fileInput.click();
});

// 文件选择事件
fileInput.addEventListener('change', (e) => {
    const file = e.target.files[0];
    if (file) {
        handleFileSelect(file);
    }
});

// 拖拽上传
uploadBox.addEventListener('dragover', (e) => {
    e.preventDefault();
    uploadBox.classList.add('dragover');
});

uploadBox.addEventListener('dragleave', () => {
    uploadBox.classList.remove('dragover');
});

uploadBox.addEventListener('drop', (e) => {
    e.preventDefault();
    uploadBox.classList.remove('dragover');

    const file = e.dataTransfer.files[0];
    if (file && file.type === 'application/pdf') {
        handleFileSelect(file);
    } else {
        alert('请上传PDF文件');
    }
});

// 处理文件选择
function handleFileSelect(file) {
    if (file.type !== 'application/pdf') {
        alert('只支持PDF文件');
        return;
    }

    if (file.size > 50 * 1024 * 1024) {
        alert('文件过大，最大支持50MB');
        return;
    }

    currentFileName = file.name;

    // 显示选中的文件
    uploadBox.querySelector('.upload-content p').textContent = `已选择: ${file.name}`;
    uploadBox.querySelector('.upload-content p').classList.add('file-selected');

    // 启用处理按钮
    processBtn.disabled = false;

    // 上传文件
    uploadFile(file);
}

// 上传文件
async function uploadFile(file) {
    const formData = new FormData();
    formData.append('file', file);

    try {
        const response = await fetch(`${API_BASE}/ocr/upload`, {
            method: 'POST',
            body: formData
        });

        const data = await response.json();

        if (response.ok) {
            currentJobId = data.job_id;
            console.log('文件上传成功，job_id:', currentJobId);
        } else {
            alert('上传失败: ' + data.detail);
        }
    } catch (error) {
        console.error('上传错误:', error);
        alert('上传失败，请重试');
    }
}

// 开始处理
processBtn.addEventListener('click', async () => {
    if (!currentJobId) {
        alert('请先上传文件');
        return;
    }

    // 隐藏上传区域，显示状态
    document.querySelector('.upload-section').style.display = 'none';
    statusSection.style.display = 'block';
    resultSection.style.display = 'none';

    try {
        // 调用处理接口
        const response = await fetch(`${API_BASE}/ocr/process`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                job_id: currentJobId,
                ocr_model: ocrModel.value
            })
        });

        const data = await response.json();

        if (response.ok) {
            // 开始轮询状态
            pollStatus();
        } else {
            alert('处理失败: ' + data.detail);
            resetUI();
        }
    } catch (error) {
        console.error('处理错误:', error);
        alert('处理失败，请重试');
        resetUI();
    }
});

// 轮询任务状态
async function pollStatus() {
    const interval = setInterval(async () => {
        try {
            const response = await fetch(`${API_BASE}/ocr/status/${currentJobId}`);
            const data = await response.json();

            statusText.textContent = data.message;

            if (data.status === 'completed') {
                clearInterval(interval);
                // 获取结果
                await showResult();
            } else if (data.status === 'failed') {
                clearInterval(interval);
                alert('处理失败: ' + data.message);
                resetUI();
            }
        } catch (error) {
            clearInterval(interval);
            console.error('状态查询错误:', error);
            alert('状态查询失败');
            resetUI();
        }
    }, 2000); // 每2秒查询一次
}

// 显示结果
async function showResult() {
    try {
        const response = await fetch(`${API_BASE}/ocr/result/${currentJobId}`);
        const data = await response.json();

        if (response.ok) {
            // 隐藏状态，显示结果
            statusSection.style.display = 'none';
            resultSection.style.display = 'block';

            // 显示统计信息
            const statsData = data.stats;
            stats.innerHTML = `
                <div class="stat-card">
                    <div class="number">${statsData.total_pages}</div>
                    <div class="label">总页数</div>
                </div>
                <div class="stat-card">
                    <div class="number">${statsData.tables}</div>
                    <div class="label">表格</div>
                </div>
                <div class="stat-card">
                    <div class="number">${statsData.figures}</div>
                    <div class="label">图片</div>
                </div>
                <div class="stat-card">
                    <div class="number">${statsData.formulas}</div>
                    <div class="label">公式</div>
                </div>
            `;

            // 显示Markdown预览（转换为HTML）
            markdownPreview.innerHTML = convertMarkdownToHTML(data.markdown);

        } else {
            alert('获取结果失败');
            resetUI();
        }
    } catch (error) {
        console.error('获取结果错误:', error);
        alert('获取结果失败');
        resetUI();
    }
}

// 简单的Markdown转HTML（仅用于预览）
function convertMarkdownToHTML(markdown) {
    let html = markdown;

    // 图片
    html = html.replace(/!\[(.*?)\]\((.*?)\)/g, '<img src="/outputs/' + currentJobId + '/$2" alt="$1">');

    // 公式（简化显示）
    html = html.replace(/\$\$(.*?)\$\$/gs, '<div style="background:#f0f0f0;padding:10px;margin:10px 0;border-left:4px solid #667eea;"><code>$$1$$</code></div>');

    // 加粗
    html = html.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');

    // 段落
    html = html.replace(/\n\n/g, '</p><p>');
    html = '<p>' + html + '</p>';

    return html;
}

// 下载Markdown
downloadBtn.addEventListener('click', () => {
    window.location.href = `${API_BASE}/ocr/download/${currentJobId}`;
});

// 重置UI
function resetUI() {
    document.querySelector('.upload-section').style.display = 'block';
    statusSection.style.display = 'none';
    resultSection.style.display = 'none';

    uploadBox.querySelector('.upload-content p').textContent = '点击或拖拽PDF文件到此处';
    uploadBox.querySelector('.upload-content p').classList.remove('file-selected');

    processBtn.disabled = true;
    currentJobId = null;
    currentFileName = null;
    fileInput.value = '';
}
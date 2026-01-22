# import cv2
# import sys

# def test_camera(index):
#     """测试指定索引的摄像头"""
#     # 打开摄像头
#     cap = cv2.VideoCapture(index, cv2.CAP_V4L2)  # CAP_V4L2指定使用Linux的V4L2驱动，兼容性更好

#     # 检查摄像头是否成功打开
#     if not cap.isOpened():
#         print(f"❌ 无法打开摄像头索引 {index}")
#         return False

#     # 设置摄像头参数（可选，和你lerobot的配置一致）
#     cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
#     cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
#     cap.set(cv2.CAP_PROP_FPS, 30)

#     # 获取实际的参数（验证是否设置成功）
#     actual_width = cap.get(cv2.CAP_PROP_FRAME_WIDTH)
#     actual_height = cap.get(cv2.CAP_PROP_FRAME_HEIGHT)
#     actual_fps = cap.get(cv2.CAP_PROP_FPS)
#     print(f"✅ 摄像头索引 {index} 打开成功")
#     print(f"  实际分辨率：{actual_width}x{actual_height}，实际帧率：{actual_fps}")

#     # 显示摄像头画面（按q退出）
#     while True:
#         ret, frame = cap.read()
#         if not ret:
#             print(f"❌ 摄像头索引 {index} 无法读取画面")
#             break

#         cv2.imshow(f"Camera {index}", frame)
#         if cv2.waitKey(1) & 0xFF == ord('q'):
#             break

#     # 释放资源
#     cap.release()
#     cv2.destroyAllWindows()
#     return True

# if __name__ == "__main__":
#     # 测试多个索引（0、1、2是最常见的，根据系统情况调整）
#     test_indexes = [0, 1, 2]
#     for idx in test_indexes:
#         print(f"\n--- 测试摄像头索引 {idx} ---")
#         test_camera(idx)


import cv2

def test_camera_realtime(index):
    """实时显示指定索引摄像头的画面（修复GUI后）"""
    # 打开摄像头，使用V4L2驱动（Linux专用，兼容性更好）
    cap = cv2.VideoCapture(index, cv2.CAP_V4L2)

    # 检查摄像头是否成功打开
    if not cap.isOpened():
        print(f"❌ 无法打开摄像头索引 {index}")
        return False

    # 设置摄像头参数（和lerobot配置一致）
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    cap.set(cv2.CAP_PROP_FPS, 30)

    print(f"✅ 摄像头索引 {index} 打开成功，按q退出画面")

    # 实时读取并显示画面
    while True:
        # 读取一帧画面
        ret, frame = cap.read()
        if not ret:
            print(f"❌ 无法读取摄像头{index}的画面")
            break

        # 显示画面
        cv2.imshow(f"Realtime Camera {index}", frame)

        # 按q键退出循环（waitKey(1)是必须的，否则窗口会卡死）
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    # 释放资源，关闭窗口
    cap.release()
    cv2.destroyAllWindows()
    return True

if __name__ == "__main__":
    # 测试你的摄像头索引（比如0和2，根据实际情况修改）
    test_camera_realtime(2)
    # 如果有第二个摄像头，再测试另一个索引
    # test_camera_realtime(2)

using System;
using System.IO;
using System.Windows;
using System.Windows.Media.Animation;
using System.Windows.Input;
using System.Windows.Threading;
using Microsoft.Win32;

namespace Player64X
{
    public partial class MainWindow : Window
    {
        const string Filter = "동영상|*.mp4;*.mkv;*.avi;*.mov;*.wmv;*.webm;*.ts;*.m2ts;*.mts;*.flv;*.m4v;*.mpg;*.mpeg;*.3gp|모든 파일|*.*";
        static readonly double[] Speeds = { 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0 };
        static readonly (string name, double ratio)[] Aspects =
        {
            ("원본", 0), ("16:9", 16.0 / 9), ("21:9", 21.0 / 9), ("32:9", 32.0 / 9), ("4:3", 4.0 / 3), ("꽉 채우기", -1)
        };

        readonly DispatcherTimer tick = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(250) };
        readonly DispatcherTimer idle = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2.5) };

        bool playing, loaded, updatingSeek, fullscreen, flipped;
        int rotation, aspectIdx, speedIdx = 3;
        double zoom = 1, panX, panY;

        bool dragging, moved;
        Point dragStart, panStart;

        WindowState prevState;
        WindowStyle prevStyle;
        ResizeMode prevResize;

        public MainWindow()
        {
            InitializeComponent();
            Video.Volume = Vol.Value;
            tick.Tick += (s, e) => UpdateTime();
            tick.Start();
            idle.Tick += (s, e) => { if (playing && !Bar.IsMouseOver) SetChrome(false); };
            Loaded += (s, e) =>
            {
                var a = Environment.GetCommandLineArgs();
                if (a.Length > 1 && File.Exists(a[1])) OpenFile(a[1]);
            };
        }

        // ---------- 파일 ----------
        void OpenFile(string path)
        {
            Video.Source = new Uri(path);
            Title = Path.GetFileName(path) + " - Player 64X";
            Hint.Visibility = Visibility.Collapsed;
            loaded = false;
            ResetView();
            Video.SpeedRatio = Speeds[speedIdx];
            Video.Play();
            SetPlaying(true);
        }

        void Open_Click(object s, RoutedEventArgs e)
        {
            var d = new OpenFileDialog { Filter = Filter };
            if (d.ShowDialog() == true) OpenFile(d.FileName);
        }

        void Window_Drop(object s, DragEventArgs e)
        {
            if (e.Data.GetData(DataFormats.FileDrop) is string[] f && f.Length > 0) OpenFile(f[0]);
        }

        void Video_Opened(object s, RoutedEventArgs e)
        {
            loaded = true;
            Seek.Maximum = Math.Max(1, Video.NaturalDuration.HasTimeSpan ? Video.NaturalDuration.TimeSpan.TotalSeconds : 1);
            TimeTot.Text = Fmt(Video.NaturalDuration.HasTimeSpan ? Video.NaturalDuration.TimeSpan : TimeSpan.Zero);
            ApplyTransform();
            Osd_Show($"{Video.NaturalVideoWidth} x {Video.NaturalVideoHeight}");
        }

        void Video_Ended(object s, RoutedEventArgs e)
        {
            Video.Stop();
            SetPlaying(false);
            SetChrome(true);
        }

        void Video_Failed(object s, ExceptionRoutedEventArgs e)
        {
            SetPlaying(false);
            MessageBox.Show("이 영상을 재생할 수 없습니다.\n\n" + e.ErrorException?.Message +
                "\n\nHEVC(H.265) 영상이면 Windows에 'HEVC 비디오 확장'이 설치되어 있어야 합니다.",
                "재생 오류", MessageBoxButton.OK, MessageBoxImage.Warning);
        }

        // ---------- 재생 ----------
        void SetPlaying(bool p)
        {
            playing = p;
            PlayBtn.Content = p ? "일시정지" : "재생";
        }

        void TogglePlay()
        {
            if (Video.Source == null) { Open_Click(null, null); return; }
            if (playing) Video.Pause(); else Video.Play();
            SetPlaying(!playing);
            SetChrome(true);
        }

        void Play_Click(object s, RoutedEventArgs e) => TogglePlay();
        void Back_Click(object s, RoutedEventArgs e) => Skip(-10);
        void Fwd_Click(object s, RoutedEventArgs e) => Skip(10);

        void Skip(double sec)
        {
            if (!loaded) return;
            var t = Video.Position + TimeSpan.FromSeconds(sec);
            if (t < TimeSpan.Zero) t = TimeSpan.Zero;
            Video.Position = t;
            UpdateTime();
            Osd_Show((sec > 0 ? "+" : "") + sec + "초");
        }

        void Seek_Changed(object s, RoutedPropertyChangedEventArgs<double> e)
        {
            if (updatingSeek || !loaded) return;
            Video.Position = TimeSpan.FromSeconds(Seek.Value);
            TimeCur.Text = Fmt(Video.Position);
        }

        void Vol_Changed(object s, RoutedPropertyChangedEventArgs<double> e)
        {
            if (Video != null) Video.Volume = Vol.Value;
        }

        void UpdateTime()
        {
            if (!loaded) return;
            updatingSeek = true;
            Seek.Value = Math.Min(Seek.Maximum, Video.Position.TotalSeconds);
            updatingSeek = false;
            TimeCur.Text = Fmt(Video.Position);
        }

        static string Fmt(TimeSpan t) =>
            t.TotalHours >= 1 ? $"{(int)t.TotalHours}:{t.Minutes:00}:{t.Seconds:00}" : $"{t.Minutes:00}:{t.Seconds:00}";

        void Speed_Click(object s, RoutedEventArgs e) => ChangeSpeed(1, true);

        void ChangeSpeed(int dir, bool wrap = false)
        {
            int n = speedIdx + dir;
            if (n >= Speeds.Length) n = wrap ? 0 : Speeds.Length - 1;
            if (n < 0) n = 0;
            speedIdx = n;
            Video.SpeedRatio = Speeds[speedIdx];
            SpeedBtn.Content = Speeds[speedIdx].ToString("0.0#") + "x";
            Osd_Show("속도 " + SpeedBtn.Content);
        }

        // ---------- 확대 / 이동 / 회전 / 비율 ----------
        void ApplyTransform()
        {
            double sw = Stage.ActualWidth, sh = Stage.ActualHeight;
            double vw = Video.NaturalVideoWidth, vh = Video.NaturalVideoHeight;
            double a = StretchFactor(sw, sh, vw, vh);

            double fit = 1;
            if (vw > 0 && vh > 0 && sw > 0 && sh > 0)
            {
                double s0 = Math.Min(sw / vw, sh / vh);
                double w = vw * s0, h = vh * s0;
                double dw = w * a, dh = h;
                if (rotation % 180 != 0) { double t = dw; dw = dh; dh = t; }
                fit = Math.Min(sw / dw, sh / dh);
            }

            FitT.ScaleX = FitT.ScaleY = fit;
            StretchT.ScaleX = a;
            FlipT.ScaleX = flipped ? -1 : 1;
            RotT.Angle = rotation;
            ZoomT.ScaleX = ZoomT.ScaleY = zoom;
            PanT.X = panX;
            PanT.Y = panY;
            ZoomBtn.Content = Math.Round(zoom * 100) + "%";
        }

        double StretchFactor(double sw, double sh, double vw, double vh)
        {
            double r = Aspects[aspectIdx].ratio;
            if (r == 0 || vw <= 0 || vh <= 0) return 1;
            double orig = vw / vh;
            if (r < 0) // 꽉 채우기: 화면 비율에 맞춰 늘림
                r = (rotation % 180 != 0) ? sh / sw : sw / sh;
            return r / orig;
        }

        void ZoomAt(Point p, double factor)
        {
            double nz = Math.Max(0.1, Math.Min(32, zoom * factor));
            double k = nz / zoom;
            double cx = p.X - Stage.ActualWidth / 2, cy = p.Y - Stage.ActualHeight / 2;
            panX = cx - k * (cx - panX);
            panY = cy - k * (cy - panY);
            zoom = nz;
            ApplyTransform();
        }

        void ResetView()
        {
            zoom = 1; panX = panY = 0; rotation = 0; flipped = false; aspectIdx = 0;
            AspectBtn.Content = "비율: 원본";
            ApplyTransform();
        }

        void Stage_MouseWheel(object s, MouseWheelEventArgs e)
        {
            ZoomAt(e.GetPosition(Stage), e.Delta > 0 ? 1.12 : 1 / 1.12);
            Osd_Show("확대 " + Math.Round(zoom * 100) + "%");
        }

        void Stage_MouseDown(object s, MouseButtonEventArgs e)
        {
            if (e.ClickCount == 2) { ToggleFullscreen(); dragging = false; return; }
            dragging = true; moved = false;
            dragStart = e.GetPosition(Stage);
            panStart = new Point(panX, panY);
            Stage.CaptureMouse();
        }

        void Stage_MouseMove(object s, MouseEventArgs e)
        {
            SetChrome(true);
            if (!dragging) return;
            var p = e.GetPosition(Stage);
            var dx = p.X - dragStart.X; var dy = p.Y - dragStart.Y;
            if (!moved && Math.Abs(dx) + Math.Abs(dy) < 4) return;
            moved = true;
            panX = panStart.X + dx;
            panY = panStart.Y + dy;
            ApplyTransform();
        }

        void Stage_MouseUp(object s, MouseButtonEventArgs e)
        {
            if (!dragging) return;
            dragging = false;
            Stage.ReleaseMouseCapture();
            if (!moved) TogglePlay();
        }

        void Stage_AnyMouseDown(object s, MouseButtonEventArgs e)
        {
            if (e.ChangedButton == MouseButton.Middle) { zoom = 1; panX = panY = 0; ApplyTransform(); Osd_Show("보기 초기화"); }
        }

        void ZoomIn_Click(object s, RoutedEventArgs e) => ZoomAt(new Point(Stage.ActualWidth / 2, Stage.ActualHeight / 2), 1.25);
        void ZoomOut_Click(object s, RoutedEventArgs e) => ZoomAt(new Point(Stage.ActualWidth / 2, Stage.ActualHeight / 2), 0.8);

        void PanBy(double dx, double dy)
        {
            panX += dx; panY += dy;
            ApplyTransform();
        }

        void ZoomReset_Click(object s, RoutedEventArgs e) { zoom = 1; panX = panY = 0; ApplyTransform(); }
        void Rotate_Click(object s, RoutedEventArgs e) => Rotate();
        void Flip_Click(object s, RoutedEventArgs e) => Flip();
        void Aspect_Click(object s, RoutedEventArgs e) => CycleAspect();

        void Rotate()
        {
            rotation = (rotation + 90) % 360;
            ApplyTransform();
            Osd_Show("회전 " + rotation + "°");
        }

        void Flip()
        {
            flipped = !flipped;
            ApplyTransform();
            Osd_Show(flipped ? "좌우반전" : "반전 해제");
        }

        void CycleAspect()
        {
            aspectIdx = (aspectIdx + 1) % Aspects.Length;
            AspectBtn.Content = "비율: " + Aspects[aspectIdx].name;
            ApplyTransform();
            Osd_Show("화면 비율 " + Aspects[aspectIdx].name);
        }

        void Window_SizeChanged(object s, SizeChangedEventArgs e) => ApplyTransform();

        // ---------- 전체화면 / UI ----------
        void Full_Click(object s, RoutedEventArgs e) => ToggleFullscreen();

        void ToggleFullscreen()
        {
            if (!fullscreen)
            {
                prevState = WindowState; prevStyle = WindowStyle; prevResize = ResizeMode;
                WindowStyle = WindowStyle.None;
                ResizeMode = ResizeMode.NoResize;
                WindowState = WindowState.Normal;
                WindowState = WindowState.Maximized;
                fullscreen = true;
                idle.Start();
            }
            else
            {
                WindowStyle = prevStyle;
                ResizeMode = prevResize;
                WindowState = prevState;
                fullscreen = false;
                SetChrome(true);
            }
        }

        void SetChrome(bool show)
        {
            Bar.Visibility = show ? Visibility.Visible : Visibility.Collapsed;
            Mouse.OverrideCursor = (!show && fullscreen) ? Cursors.None : null;
            if (show) { idle.Stop(); idle.Start(); }
        }

        void Osd_Show(string text)
        {
            Osd.Text = text;
            var a = new DoubleAnimationUsingKeyFrames();
            a.KeyFrames.Add(new LinearDoubleKeyFrame(1, KeyTime.FromPercent(0)));
            a.KeyFrames.Add(new LinearDoubleKeyFrame(1, KeyTime.FromPercent(0.6)));
            a.KeyFrames.Add(new LinearDoubleKeyFrame(0, KeyTime.FromPercent(1)));
            a.Duration = TimeSpan.FromSeconds(1.6);
            Osd.BeginAnimation(OpacityProperty, a);
        }

        // ---------- 키보드 ----------
        void Window_PreviewKeyDown(object s, KeyEventArgs e)
        {
            var c = Stage.IsMouseOver ? Mouse.GetPosition(Stage) : new Point(Stage.ActualWidth / 2, Stage.ActualHeight / 2);
            bool h = true;
            if (Keyboard.Modifiers == ModifierKeys.Control &&
                (e.Key == Key.Left || e.Key == Key.Right || e.Key == Key.Up || e.Key == Key.Down))
            {
                double step = 80;
                PanBy(e.Key == Key.Left ? step : e.Key == Key.Right ? -step : 0,
                      e.Key == Key.Up ? step : e.Key == Key.Down ? -step : 0);
                e.Handled = true;
                return;
            }
            switch (e.Key)
            {
                case Key.Space: TogglePlay(); break;
                case Key.Left: Skip(Keyboard.Modifiers == ModifierKeys.Shift ? -30 : -5); break;
                case Key.Right: Skip(Keyboard.Modifiers == ModifierKeys.Shift ? 30 : 5); break;
                case Key.Up: Vol.Value = Math.Min(1, Vol.Value + 0.05); Osd_Show("볼륨 " + (int)(Vol.Value * 100)); break;
                case Key.Down: Vol.Value = Math.Max(0, Vol.Value - 0.05); Osd_Show("볼륨 " + (int)(Vol.Value * 100)); break;
                case Key.F: case Key.Enter: ToggleFullscreen(); break;
                case Key.Escape: if (fullscreen) ToggleFullscreen(); break;
                case Key.OemPlus: case Key.Add: ZoomAt(c, 1.25); Osd_Show("확대 " + Math.Round(zoom * 100) + "%"); break;
                case Key.OemMinus: case Key.Subtract: ZoomAt(c, 0.8); Osd_Show("확대 " + Math.Round(zoom * 100) + "%"); break;
                case Key.D0: case Key.NumPad0: zoom = 1; panX = panY = 0; ApplyTransform(); Osd_Show("보기 초기화"); break;
                case Key.R: Rotate(); break;
                case Key.H: Flip(); break;
                case Key.A: CycleAspect(); break;
                case Key.OemOpenBrackets: ChangeSpeed(-1); break;
                case Key.OemCloseBrackets: ChangeSpeed(1); break;
                case Key.O: Open_Click(null, null); break;
                default: h = false; break;
            }
            if (h) e.Handled = true;
        }
    }
}

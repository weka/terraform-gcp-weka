package scale

import "testing"

func Test_calculateDeactivateTarget(t *testing.T) {
	type args struct {
		nHealthy      int
		nUnhealthy    int
		nDeactivating int
		desired       int
	}
	tests := []struct {
		name string
		args args
		want int
	}{
		{"manualDeactivate", args{9, 0, 1, 10}, 1},
		{"downscale", args{20, 0, 0, 10}, 10},
		{"downscaleP2", args{10, 0, 6, 10}, 6},
		{"downfailures", args{8, 2, 6, 10}, 6},
		{"failures", args{20, 10, 0, 30}, 2},
		{"failuresP2", args{20, 8, 2, 30}, 2},
		{"upscale", args{20, 0, 0, 30}, 0},
		{"upscaleFailures", args{20, 3, 0, 30}, 2},
		{"totalfailure", args{0, 20, 0, 30}, 2},
		{"totalfailureP2", args{0, 18, 2, 30}, 2},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := calculateDeactivateTarget(tt.args.nHealthy, tt.args.nUnhealthy, tt.args.nDeactivating, tt.args.desired); got != tt.want {
				t.Errorf("calculateDeactivateTarget() = %v, want %v", got, tt.want)
			}
		})
	}
}

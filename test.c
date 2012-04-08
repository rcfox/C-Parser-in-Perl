enum test1 {
	a
};

enum test2 {
	b,
	c
};

enum test3 {
	d = 1
};

enum test4 {
	e = 1,
	f = 2
};

enum {
	g
};

enum {
	h = 1,
	i = 2
};

typedef struct foo {
	int a;
	int b;
	int c;
	int d;
} foomp;

struct foo {
	int a,b,****d,e;
} foomp;


union a{
	struct {
		int dfg;
		int fg;
		union {
			int q;
			int e;
		} u;
	} *f;
	int a;
	int b;
};

union dfdf{
	int c;
	const int d;
};


int main (int argc, char* argv[]) {
	return 0;
}


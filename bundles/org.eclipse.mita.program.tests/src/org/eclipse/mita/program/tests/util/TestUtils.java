package org.eclipse.mita.program.tests.util;

import static org.mockito.Mockito.mock;

import com.google.inject.Binder;

public class TestUtils {
	public static <T> T mockBind(Binder b, Class<T> clazz) {
		T instance = mock(clazz);
		b.bind(clazz).toInstance(instance);
		return instance;
	}
}

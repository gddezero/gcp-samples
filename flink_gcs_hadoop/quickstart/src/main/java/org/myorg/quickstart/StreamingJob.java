/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.myorg.quickstart;

import org.apache.flink.api.common.typeinfo.TypeHint;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.functions.source.datagen.DataGeneratorSource;
import org.apache.flink.api.common.serialization.SimpleStringEncoder;
import org.apache.flink.core.fs.Path;
import org.apache.flink.streaming.api.functions.sink.filesystem.StreamingFileSink;
import org.apache.flink.streaming.api.functions.sink.filesystem.rollingpolicies.DefaultRollingPolicy;
import java.util.concurrent.TimeUnit;


public class StreamingJob {
	
	public static void main(String[] args) throws Exception {
		// set up the streaming execution environment
		final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
		env.enableCheckpointing(60000);
		env.getCheckpointConfig().setMinPauseBetweenCheckpoints(500);
		env.getCheckpointConfig().setCheckpointTimeout(60000);
		env.getCheckpointConfig().setMaxConcurrentCheckpoints(1);
		env.getCheckpointConfig().enableUnalignedCheckpoints();




		 DataGeneratorSource<TrafficData> trafficDataDataGeneratorSource = new DataGeneratorSource<>(new TrafficData.TrafficDataGenerator(), 10L);
		 // 添加source
		 DataStream<TrafficData> ds = env.addSource(trafficDataDataGeneratorSource)
				 // 指定返回类型
				 .returns(new TypeHint<TrafficData>() {
				 });
				 // 输出
				//  .print();
		
		// Sink to GCS
		final StreamingFileSink<TrafficData> sink = StreamingFileSink
			.forRowFormat(new Path("gs://forrest-bigdata-bucket/data/quickstart-app"), new SimpleStringEncoder<TrafficData>("UTF-8"))
			.withRollingPolicy(
				DefaultRollingPolicy.builder()
					.withRolloverInterval(TimeUnit.MINUTES.toMillis(1))
					.withInactivityInterval(TimeUnit.MINUTES.toMillis(1))
					.withMaxPartSize(1024 * 1024)
					.build())
			.build();

		ds.addSink(sink);

		// execute program
		env.execute("Flink Streaming Java API Skeleton");
	}
}
package org.myorg.quickstart;

import org.apache.commons.math3.random.RandomDataGenerator;
import org.apache.flink.api.common.functions.RuntimeContext;
import org.apache.flink.runtime.state.FunctionInitializationContext;
import org.apache.flink.streaming.api.functions.source.datagen.DataGenerator;
import java.io.Serializable;

public class TrafficData implements Serializable {
    private static final long serialVersionUID = 1L;
    /** 用户id */
    private long userId;
    /** 用户所属城市id */
    private int cityId;
    /** 流量时间 */
    private long trafficTime;
    /** 流量大小 */
    private final double traffic;

    public TrafficData(long userId, int cityId, long trafficTime, double traffic) {
        this.userId = userId;
        this.cityId = cityId;
        this.trafficTime = trafficTime;
        this.traffic = traffic;
    }

    /**
     * 自定义的数据生成器，用于生成随机的TrafficData对象
     */
    static class TrafficDataGenerator implements DataGenerator<TrafficData> {
        /** 随机数据生成器对象 */
        private RandomDataGenerator generator;

        @Override
        public void open(String name, FunctionInitializationContext context, RuntimeContext runtimeContext) throws Exception {
            // 实例化生成器对象
            generator = new RandomDataGenerator();
        }
        /**
         * 是否有下一个
         *
         * @return
         */
        @Override
        public boolean hasNext() {
            return true;
        }
        @Override
        public TrafficData next() {
            // 使用随机生成器生成数据，构造流量对象
            return new TrafficData(
                    generator.nextInt(1, 100),
                    generator.nextInt(1, 10),
                    System.currentTimeMillis(),
                    generator.nextUniform(0, 1)
            );
        }
    }

    public long getUserId() {
        return userId;
    }
    public void setUserId(long userId) {
        this.userId = userId;
    }
    public int getCityId() {
        return cityId;
    }
    public void setCityId(int cityId) {
        this.cityId = cityId;
    }
    public long getTrafficTime() {
        return trafficTime;
    }
    public void setTrafficTime(long trafficTime) {
        this.trafficTime = trafficTime;
    }
    public double getTraffic() {
        return traffic;
    }
    @Override
    public String toString() {
        return "TrafficData{" +
                "userId=" + userId +
                ", cityId=" + cityId +
                ", trafficTime=" + trafficTime +
                ", traffic=" + traffic +
                '}';
    }
}
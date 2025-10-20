import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
    vus: 200, // number of virtual (parallel) users
    duration: '30s', // test duration
};


const city = 'Rome';

// warming-up request
export function setup() {
    http.get('http://localhost:8081/weather?place=' + city);
}

// virtual user method
export default function () {
    const res = http.get('http://localhost:8081/weather?place=' + city);

    if (res.status !== 200) {
        console.log('HTTP ', res.status, ' Response Body:', res.body);
    }

    check(res, {
        'status is 200': (r) => r.status === 200,
    });
}